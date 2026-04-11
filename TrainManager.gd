extends Node3D

@export var train_scene: PackedScene
@export var player: Node3D
@export var track_root: Node3D

@export var start_distance := 0.0

var traversal_sign := 1.0

var train: Node3D
var current_segment: Node3D
var distance_along := 0.0
var previous_train_transform: Transform3D

@export var station_timetable: Array[String] = []
var timetable_index := 0

func _ready() -> void:
	if track_root:
		current_segment = track_root.get_node(track_root.start_segment)
	
	player.train_throttle_changed.connect(_on_throttle_changed)
	
	spawn_train()
	# previous_train_transform = train.global_transform
	var t = current_segment.get_sample_transform(distance_along)

	if traversal_sign < 0:
		var up = t.basis.y.normalized()
		t.basis = t.basis.rotated(up, PI)

	previous_train_transform = t

func _physics_process(delta: float) -> void:
	if not train or not current_segment:
		return
	
	if Input.is_action_just_pressed("switch_junction"):
		switch_junction()
	
	var delta_move = train.speed * delta * traversal_sign
	distance_along += delta_move
	
	var curve = current_segment.path.curve
	var length = curve.get_baked_length()

	if distance_along > length or distance_along < 0.0:
		move_to_adjacent_segment()
		return
	
	# var target_transform = current_segment.get_sample_transform(distance_along)
	var target_transform = current_segment.get_sample_transform(distance_along)

	if traversal_sign < 0:
		var up = target_transform.basis.y.normalized()
		target_transform.basis = target_transform.basis.rotated(up, PI)
	
	var delta_transform = previous_train_transform.affine_inverse() * target_transform
	move_world_relative_to_player(delta_transform)
	
	# previous_train_transform = train.global_transform
	var t = current_segment.get_sample_transform(distance_along)

	if traversal_sign < 0:
		var up = t.basis.y.normalized()
		t.basis = t.basis.rotated(up, PI)

	previous_train_transform = t

# -------------------------
# CORE FIX (Idea 1)
# -------------------------

func get_entry_distance(from_pos: Vector3, segment: Node3D) -> float:
	var start_t = segment.get_curve_start_point()
	var end_t = segment.get_curve_end_point()
	
	var d_start = from_pos.distance_to(start_t.origin)
	var d_end = from_pos.distance_to(end_t.origin)

	if d_start < d_end:
		traversal_sign = 1.0
		return 0.0
	else:
		traversal_sign = -1.0
		return segment.path.curve.get_baked_length()

func move_to_adjacent_segment():
	var length = current_segment.path.curve.get_baked_length()

	var exiting_from_end = distance_along > length
	var exiting_from_start = distance_along < 0.0

	var next: Node = null

	if exiting_from_end:
		next = get_connected_segment(current_segment, true)
	elif exiting_from_start:
		next = get_connected_segment(current_segment, false)

	if not next:
		train.speed = 0.0
		distance_along = length if exiting_from_end else 0.0
		return
	
	var exit_pos = previous_train_transform.origin
	current_segment = next

	# Remember, we set traversal_sign within this function. Not like we'll ever forget about that...
	# TODO pull out traversal_sign setting so we don't forget about it
	distance_along = get_entry_distance(exit_pos, current_segment)
	distance_along = clamp(distance_along, 0.01, current_segment.path.curve.get_baked_length() - 0.01)
	
	# previous_train_transform = current_segment.get_sample_transform(distance_along)
	var t = current_segment.get_sample_transform(distance_along)

	if traversal_sign < 0:
		var up = t.basis.y.normalized()
		t.basis = t.basis.rotated(up, PI)

	previous_train_transform = t

# -------------------------
# EXISTING SYSTEMS (unchanged)
# -------------------------

func move_world_relative_to_player(delta_transform: Transform3D) -> void:
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

# func get_connected_segment(segment: Node, forward: bool) -> Node:
# 	var list = segment.next_segments
# 	if list.size() == 0:
# 		return null
	
# 	var index = segment.next_junction_index
# 	return list[index]

func get_connected_segment(segment: Node, forward: bool) -> Node:
	var list = segment.next_segments if forward else segment.previous_segments
	
	if list.size() == 0:
		return null
	
	var index = segment.next_junction_index if forward else segment.previous_junction_index
	
	return list[index]

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
	player.on_seated()

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
		
		current = get_connected_segment(current, traversal_sign == 1)
		
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
		1: return "Forward"
		-1: return "Reverse"
		2: return "Stopped"
	return "Unknown"

func build_debug_text():
	if not current_segment:
		return "No segment"
	
	var text := ""
	
	# --- Core Info ---
	text += "Speed: %.2f\n" % train.speed
	text += "Throttle: %.2f\n" % train.throttle
	text += "Direction: %s\n" % get_direction_string(traversal_sign)
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
	return 1 if train.direction == train.Direction.FORWARD else -1
