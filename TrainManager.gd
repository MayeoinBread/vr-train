extends Node3D

@export var train_scene: PackedScene
@export var player: Node3D
@export var track_root: Node3D

@export var start_distance := 0.0

var train: Node3D
var current_segment: Node3D
var distance_along := 0.0
var previous_train_transform: Transform3D

var entering_forward := true
var segment_forward := true
var previous_segment: Node = null
var last_connection: Node = null

@export var station_timetable: Array[String] = []
var timetable_index := 0

func _ready() -> void:
	if track_root:
		current_segment = track_root.get_node(track_root.start_segment)
	
	player.train_throttle_changed.connect(_on_throttle_changed)
	
	spawn_train()
	# previous_train_transform = train.global_transform
	var t = current_segment.get_sample_transform(distance_along)

	if not segment_forward:
		var up = t.basis.y.normalized()
		t.basis = t.basis.rotated(up, PI)

	previous_train_transform = t

func _physics_process(delta: float) -> void:
	if not train or not current_segment:
		return
	
	if Input.is_action_just_pressed("switch_junction"):
		switch_junction()
	
	# var delta_move = train.speed * delta
	# distance_along += delta_move if segment_forward else -delta_move
	distance_along += train.speed * delta
	
	var curve = current_segment.path.curve
	var length = curve.get_baked_length()

	if distance_along > length:
		distance_along = length - 0.001
		move_to_adjacent_segment(true)
	elif distance_along < 0.0:
		distance_along = 0.001
		move_to_adjacent_segment(false)
	
	# var target_transform = current_segment.get_sample_transform(distance_along)
	var target_transform = current_segment.get_sample_transform(distance_along)

	if not segment_forward:
		var up = target_transform.basis.y.normalized()
		target_transform.basis = target_transform.basis.rotated(up, PI)
	
	var delta_transform = previous_train_transform.affine_inverse() * target_transform
	move_world_relative_to_player(delta_transform)
	
	# previous_train_transform = train.global_transform
	var t = current_segment.get_sample_transform(distance_along)

	if not segment_forward:
		var up = t.basis.y.normalized()
		t.basis = t.basis.rotated(up, PI)

	previous_train_transform = t

# -------------------------
# CORE FIX (Idea 1)
# -------------------------

func move_to_adjacent_segment(exited_at_end: bool):
	var from_segment = current_segment

	var candidates = current_segment.next_segments if exited_at_end else current_segment.previous_segments
	
	if candidates.size() == 0:
		train.speed = 0.0
		return

	var next: Node = null

	# FIRST: if we already came from somewhere, try to CONTINUE along same connection
	if last_connection:
		for seg in candidates:
			if seg == last_connection:
				next = seg
				break

	# SECOND: fallback to junction selection
	if not next:
		var index = current_segment.next_junction_index if exited_at_end else current_segment.previous_junction_index
		next = candidates[index]

	# STORE connection for next transition
	last_connection = from_segment

	current_segment = next

	# ENTRY SIDE (GEOMETRY)
	var start_t = current_segment.get_curve_start_point()
	var end_t = current_segment.get_curve_end_point()

	var exit_pos = previous_train_transform.origin

	var d_start = exit_pos.distance_to(start_t.origin)
	var d_end = exit_pos.distance_to(end_t.origin)

	if d_start < d_end:
		distance_along = 0.0
		segment_forward = true
	else:
		distance_along = current_segment.path.curve.get_baked_length()
		segment_forward = false

	# SNAP INSIDE SEGMENT
	if segment_forward:
		distance_along += 0.05
	else:
		distance_along -= 0.05

	var t = current_segment.get_sample_transform(distance_along)

	if not segment_forward:
		var up = t.basis.y.normalized()
		t.basis = t.basis.rotated(up, PI)

	previous_train_transform = t

func get_entry_distance(from_pos: Vector3, segment: Node3D) -> float:
	var start_t = segment.get_curve_start_point()
	var end_t = segment.get_curve_end_point()

	var d_start = from_pos.distance_to(start_t.origin)
	var d_end = from_pos.distance_to(end_t.origin)

	return 0.0 if d_start < d_end else segment.path.curve.get_baked_length()

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

	var dir = 1 if segment_forward else -1

	if current_segment.can_switch_junction(dir):
		current_segment.switch_junction(dir)

func get_connected_segment(segment: Node, forward: bool) -> Node:
	var list = segment.next_segments if forward else segment.previous_segments
	
	if list.size() == 0:
		return null
	
	# CRITICAL: pick the segment that is NOT the one we came from
	for s in list:
		if s != segment:
			return s
	
	# fallback (dead end or only one connection)
	return list[0]

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
		if segment_forward \
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
		
		current = get_connected_segment(current, true)
		
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
	text += "Direction: %s\n" % ("Forward" if segment_forward else "Reverse")
	text += "Segment: %s\n" % current_segment.name
	text += "Distance: %.2f\n" % distance_along
	
	# --- Junction ---
	text += "\n-- Junction --\n"
	
	# TODO this needs sorting
	if segment_forward:
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
