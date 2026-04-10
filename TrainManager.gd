extends Node3D

enum TravelDirection {
	FORWARD,
	REVERSE
}

var travel_direction := TravelDirection.FORWARD

@export var train_scene: PackedScene
@export var player: Node3D
@export var track_root: Node3D

@export var start_distance := 0.0

@export var marker_distance := 5.0  # meters along branch

@export var station_timetable: Array[String] = []
var timetable_index := 0

var junction_markers: Array[MeshInstance3D] = []

var was_stopped_at_station := false

var train: Node3D
var current_segment: Node3D
var distance_along := 0.0
var previous_train_transform: Transform3D

var last_target_transform: Transform3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if track_root:
		current_segment = track_root.get_node(track_root.start_segment)
	
	player.train_throttle_changed.connect(Callable(self, "_on_throttle_changed"))
	
	spawn_train()
	previous_train_transform = train.global_transform

func _process(_delta: float) -> void:
	var now := is_stopped_at_station()
	
	if now and not was_stopped_at_station:
		_on_station_stop(current_segment)
	
	was_stopped_at_station = now
	
func _physics_process(delta: float) -> void:
	if not train or not current_segment:
		return
	
	sync_travel_direction()
	
	# Desktop input
	if Input.is_action_just_pressed("switch_junction"):
		switch_junction()
	
	# Update train speed
	distance_along += train.speed * delta
	
	var curve = current_segment.path.curve
	var length = curve.get_baked_length()
	
	# Handle segment transitions
	if distance_along > length:
		move_to_next_segment()
		return
	
	if distance_along < 0.0:
		move_to_previous_segment()
		return
	
	# Sample target transform on current segment
	#var target_transform = current_segment.global_transform * curve.sample_baked_with_rotation(distance_along)
	var seg_xform := current_segment.global_transform.orthonormalized()
	var target_transform = seg_xform * curve.sample_baked_with_rotation(distance_along)
	last_target_transform = target_transform
	
	# Compute delta motion relative to previous frame
	var delta_transform = previous_train_transform.affine_inverse() * target_transform
	
	# Apply delta to the world (train + environment)
	move_world_relative_to_player(delta_transform)
	
	# Store for next frame
	previous_train_transform = train.global_transform

func move_world_relative_to_player(delta_transform: Transform3D) -> void:
	# Compute inverse so objects move opposite to train movement
	var inv_delta = delta_transform.affine_inverse()
	var player_inv := player.global_transform.affine_inverse()
	var base := player.global_transform
	
	for obj in get_tree().get_nodes_in_group("movable_world"):
		var local_offset = player_inv * obj.global_transform
		obj.global_transform = base * inv_delta * local_offset

func switch_junction():
	if not train or not current_segment:
		return
	
	if not within_toggle_distance():
		return
		
	if current_segment.can_switch_junction(travel_sign()):
		current_segment.switch_junction(travel_sign())

func move_to_next_segment():
	var old_transform = previous_train_transform
	
	var next = get_connected_segment(current_segment, travel_direction == TravelDirection.FORWARD)
	
	if next:
		current_segment = next
		distance_along = 0.0
		var new_start = current_segment.global_transform * current_segment.path.curve.sample_baked_with_rotation(distance_along)
		var delta_transform = old_transform.affine_inverse() * new_start
		move_world_relative_to_player(delta_transform)
		previous_train_transform = last_target_transform
	else:
		distance_along = current_segment.path.curve.get_baked_length()
		train.speed = 0.0

func move_to_previous_segment():
	var old_transform = previous_train_transform
	
	var previous = get_connected_segment(current_segment, travel_direction == TravelDirection.FORWARD)
	
	if previous:
		current_segment = previous
		var m_len = current_segment.path.curve.get_baked_length()
		distance_along = min(m_len, m_len)
		var new_start = current_segment.global_transform * current_segment.path.curve.sample_baked_with_rotation(distance_along)
		var delta_transform = old_transform.affine_inverse() * new_start
		move_world_relative_to_player(delta_transform)
		previous_train_transform = last_target_transform
	else:
		distance_along = 0.0
		train.speed = 0.0

func choose_segment(forward: bool):
	var index = current_segment.next_junction_index if forward else current_segment.previous_junction_index
	
	if forward:
		if current_segment.next_segments.size() == 0:
			return null
		return current_segment.next_segments[index]
	else:
		if current_segment.previous_segments.size() == 0:
			return null
		return current_segment.previous_segments[index]

func _on_throttle_changed(value: float, reset := false) -> void:
	train.set_throttle(value, reset)
	
func spawn_train() -> void:
	if not train_scene:
		return
	
	train = train_scene.instantiate()
	add_child(train)
	train.train_manager = self
	current_segment = track_root.get_node(track_root.start_segment)
	distance_along = start_distance
	
	call_deferred("attach_player_to_train")

func attach_player_to_train() -> void:
	var seat = train.get_node("SeatAnchor")
	player.set_seat_anchor(seat)
	
	# Update XROrigin3D:
	player.on_seated()

func switch_train(new_train_scene: PackedScene) -> void:
	# Remove old
	if train:
		train.queue_free()
	
	# Spawn new
	train_scene = new_train_scene
	spawn_train()

func within_toggle_distance() -> bool:
	var length = current_segment.path.curve.get_baked_length()
	
	return (distance_along < (length - current_segment.junction_commit_distance)) \
			if travel_sign() > 0 \
			else distance_along > current_segment.junction_commit_distance

func get_station_from_segment(segment: Node):
	if segment:
		return segment.get_station()
	return null

func get_next_station_info(lookahead_segments: int = 5) -> Dictionary:
	var info = {
		"station": null,
		"distance": -1.0
	}
	
	var current = current_segment
	var direction = travel_direction
	var distance = 0.0
	var remaining_in_segment = current.path.curve.get_baked_length() - distance_along

	for i in range(lookahead_segments):
		if not current:
			break
			
		distance += remaining_in_segment

		if current.station:
			info.station = current.station
			info.distance = distance
			return info
		
		current = get_connected_segment(current, direction == TravelDirection.FORWARD)
		
		if current:
			remaining_in_segment = current.path.curve.get_baked_length()
		else:
			break
	
	return info

func is_stopped_at_station() -> bool:
	if not current_segment:
		return false
	if not current_segment.is_station:
		return false
	if not train.is_stopped():
		return false
	return current_segment.is_train_stopped_at_station(distance_along)

func _on_station_stop(segment):
	if timetable_index >= station_timetable.size():
		return
	
	var expected = station_timetable[timetable_index]
	
	if segment.station.station_name == expected:
		print("Correct station:", expected)
		timetable_index += 1
	else:
		print("Wrong station. Expected:", expected, "Got:", segment.station.station_name)

func get_direction_string(dir):
	match dir:
		0: return "Forward"
		1: return "Reverse"
		2: return "Stopped"
	return "Unknown"

func build_debug_text():
	if not current_segment:
		return "No segment"
	
	var text := ""
	
	# --- Core Info ---
	text += "Speed: %.2f\n" % train.speed
	text += "Throttle: %.2f\n" % train.throttle
	text += "Direction: %s\n" % get_direction_string(travel_direction)
	text += "Segment: %s\n" % current_segment.name
	text += "Distance: %.2f\n" % distance_along
	
	# --- Junction ---
	text += "\n-- Junction --\n"
	
	if travel_sign() > 0:
		text += "Next count: %d\n" % current_segment.next_segments.size()
		text += "Selected: %d\n" % current_segment.next_junction_index
	else:
		text += "Prev count: %d\n" % current_segment.previous_segments.size()
		text += "Selected: %d\n" % current_segment.previous_junction_index
	
	# --- Station ---
	text += "\n-- Station --\n"
	var station_info = get_next_station_info(5)
	if station_info.station:
		text += "Next station: %s\nDistance: %.2f m" % [station_info.station.station_name, station_info.distance]
	else:
		text += "No station ahead"
	
	return text

func get_connected_segment(segment: Node, forward: bool) -> Node:
	if forward:
		if segment.next_segments.size() == 0:
			return null
		return segment.next_segments[segment.next_junction_index]
	else:
		if segment.previous_segments.size() == 0:
			return null
		return segment.previous_segments[segment.previous_junction_index]

func sync_travel_direction():
	if train.direction == train.Direction.FORWARD:
		travel_direction = TravelDirection.FORWARD
	else:
		travel_direction = TravelDirection.REVERSE

func get_segment_from_current() -> Node:
	return get_connected_segment(current_segment, travel_sign() > 0)

func get_available_exits(segment: Node) -> Array:
	return segment.next_segments + segment.previous_segments

func get_exit(segment: Node, index: int, forward: bool) -> Node:
	if forward:
		if segment.next_segments.size() == 0:
			return null
		return segment.next_segments[index % segment.next_segments.size()]
	else:
		if segment.previous_segments.size() == 0:
			return null
		return segment.previous_segments[index % segment.previous_segments.size()]

func travel_sign() -> int:
	return 1 if travel_direction == TravelDirection.FORWARD else -1
