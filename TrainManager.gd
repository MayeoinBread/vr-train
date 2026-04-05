extends Node3D

@export var train_scene: PackedScene
@export var player: Node3D
@export var track_root: Node3D

@export var start_distance := 0.0

@export var marker_distance := 5.0  # meters along branch

var junction_markers: Array[MeshInstance3D] = []

var train: Node3D
var current_segment: Node3D
var distance_along := 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if track_root:
		current_segment = track_root.get_node(track_root.start_segment)
	player.train_throttle_changed.connect(Callable(self, "_on_throttle_changed"))
	spawn_train()
	
func _process(delta: float) -> void:
	if not train or not current_segment:
		return
		
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
	
	update_train_transform()

func switch_junction():
	if not train or not current_segment:
		return
	
	if not can_switch_junction():
		return
	
	if train.direction == train.Direction.FORWARD:
		var count = current_segment.next_segments.size()
		if count > 1:
			current_segment.next_junction_index = (current_segment.next_junction_index + 1) % count
	elif train.direction == train.Direction.REVERSE:
		var count = current_segment.previous_segments.size()
		if count > 1:
			current_segment.previous_junction_index = (current_segment.previous_junction_index + 1) % count
	
	update_junction_markers()

func move_to_next_segment():
	var next = choose_next_segment()
	
	if next:
		current_segment = next
		distance_along = 0.0
	else:
		distance_along = current_segment.path.curve.get_baked_length()
		train.speed = 0.0

func move_to_previous_segment():
	var previous = choose_previous_segment()
	
	if previous:
		current_segment = previous
		distance_along = current_segment.path.curve.get_baked_length()
	else:
		distance_along = 0.0
		train.speed = 0.0

func choose_next_segment():
	if current_segment.next_segments.size() == 0:
		return null
	
	var index = current_segment.next_junction_index
	return current_segment.get_next_segment(index)

func choose_previous_segment():
	if current_segment.previous_segments.size() == 0:
		return null
	
	var index = current_segment.previous_junction_index
	return current_segment.get_previous_segment(index)

func _on_throttle_changed(value: float) -> void:
	train.set_throttle(value)
	
func spawn_train() -> void:
	if not train_scene:
		return
	
	train = train_scene.instantiate()
	add_child(train)
	train.train_manager = self
	current_segment = track_root.get_node(track_root.start_segment)
	distance_along = start_distance
	
	update_train_transform()
	call_deferred("attach_player_to_train")

func update_train_transform() -> void:
	if not current_segment:
		return
	
	var curve = current_segment.path.curve
	var local_transform = curve.sample_baked_with_rotation(distance_along)
	# NOTE would need this if the Path3D itself was rotated in the Segment scene?
	#train.global_transform.origin = current_segment.to_global(local_transform.origin)
	#train.global_transform.basis = current_segment.global_transform.basis * local_transform.basis
	train.global_transform = current_segment.global_transform * local_transform

func attach_player_to_train() -> void:
	var seat = train.get_node("SeatAnchor")
	
	# Reparent player to train
	player.get_parent().remove_child(player)
	seat.add_child(player)
	
	# Reset local transform so player snaps to seat
	player.transform = Transform3D.IDENTITY

func switch_train(new_train_scene: PackedScene) -> void:
	# Remove old
	if train:
		train.queue_free()
	
	# Spawn new
	train_scene = new_train_scene
	spawn_train()

func create_marker(color: Color) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 0.2
	m.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	
	add_child(m)
	return m

func clear_markers():
	for m in junction_markers:
		if is_instance_valid(m):
			m.queue_free()
	junction_markers.clear()

func update_junction_markers():
	clear_markers()
	
	if not current_segment:
		return
	
	if train.direction == train.Direction.FORWARD:
		show_forward_markers()
	elif train.direction == train.Direction.REVERSE:
		show_backward_markers()
	else:
		show_forward_markers()
		show_backward_markers()

func show_forward_markers():
	var count = current_segment.next_segments.size()
	if count == 0:
		return
	
	for i in count:
		var seg = current_segment.get_next_segment(i)
		if not seg:
			continue
		
		# position slightly INTO the next segment
		var t = seg.get_point_on_curve(marker_distance)
		
		var color = Color(0, 1, 0)
		if i == current_segment.next_junction_index:
			color = Color(1, 1, 0)
		
		var marker = create_marker(color)
		marker.global_transform = t
		
		junction_markers.append(marker)

func show_backward_markers():
	var count = current_segment.previous_segments.size()
	if count == 0:
		return

	for i in count:
		var seg = current_segment.get_previous_segment(i)
		if not seg:
			continue

		# position slightly INTO the previous segment (from its end)
		var length = seg.path.curve.get_baked_length()
		var t = seg.get_point_on_curve(length - marker_distance)

		var color = Color(1, 0, 0)
		if i == current_segment.previous_junction_index:
			color = Color(1, 1, 0)

		var marker = create_marker(color)
		marker.global_transform = t

		junction_markers.append(marker)

func can_switch_junction() -> bool:
	var length = current_segment.path.curve.get_baked_length()
	return distance_along < (length - current_segment.junction_commit_distance)

func get_station_from_segment(segment: Node):
	if segment:
		return segment.get_station()
	return null

func get_next_segment_from(seg: Node) -> Node:
	if seg.next_segments.size() == 0:
		return null
	return seg.next_segments[seg.next_junction_index]

func get_previous_segment_from(seg: Node) -> Node:
	if seg.previous_segments.size() == 0:
		return null
	return seg.previous_segments[seg.previous_junction_index]

func get_next_station_info(lookahead_segments: int = 5) -> Dictionary:
	var info = {
		"station": null,
		"distance": -1.0
	}
	
	var current = current_segment
	var direction = train.direction
	var distance = 0.0
	var remaining_in_segment = current.path.curve.get_baked_length() - distance_along

	for i in range(lookahead_segments):
		if not current:
			break
			
		distance += remaining_in_segment
		
		# TODO distance should be to stop point of station, not the end of it...

		if current.station:
			info.station = current.station
			info.distance = distance
			return info
		
		current = get_previous_segment_from(current) if direction == train.Direction.REVERSE else get_next_segment_from(current)
		if current:
			remaining_in_segment = current.path.curve.get_baked_length()
		else:
			break
	
	return info
