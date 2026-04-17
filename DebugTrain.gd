extends Node3D

enum TrackVisualState {
	JUNCTION_PREVIEW,
	CRUISE_PREVIEW
}

var visual_state: TrackVisualState = TrackVisualState.CRUISE_PREVIEW

@export var world_anchor: Node3D
@export var spawn_point_index: int = 0

@export var is_player_controlled: bool = false

@export var speed: float = 2.0
@export var auto_start: bool = true

@export var switch_cutoff_distance := 5.0

@export var indicator_scene: PackedScene

@export var lookahead_steps := 3
@export var lookahead_spacing := 3.0

var active_indicator: Node3D
var junction_indicators: Array[Node3D] = []
var indicator_materials: Array[StandardMaterial3D] = []

var current_port: Node3D
var current_segment: Node3D

var distance_along: float = 0.0
var direction: int = 1

# var last_pos: Vector3
var previous_train_transform: Transform3D

var pending_switch_index: int = 0

func _ready() -> void:
	TrainManager.register_train(self)
	
	if is_player_controlled:
		TrainManager.set_active_train(self)
	
	if auto_start:
		reset()
	
	RailGraphManager.junction_changed.connect(_on_junction_changed)

func _exit_tree() -> void:
	TrainManager.unregister_train(self)

func reset() -> void:
	var port = RailGraphManager.get_spawn_port(spawn_point_index)
	if port:
		_attach_to_port(port)

func _attach_to_port(port: Node3D):
	current_port = port
	current_segment = port.get_parent()

	var curve: Curve3D = current_segment.path.curve
	var length := curve.get_baked_length()

	if port.name == "PortA":
		distance_along = 0.0
		direction = 1
	else:
		distance_along = length
		direction = -1

	# previous_train_transform = current_segment.get_sample_transform(distance_along)
	# if TrainManager.active_train == self:
	# 	world_anchor.global_transform = current_segment.get_sample_transform(distance_along)

	var start_transform = current_segment.get_sample_transform(distance_along)
	print("Origin for train:")
	print(start_transform)

	if TrainManager.active_train == self:
		print("ACTIVE TRAIN")
		_align_world_to_spawn(start_transform)
	
	previous_train_transform = current_segment.get_sample_transform(distance_along)

	update_indicators(_get_exit_port())
	# _reset_indicator_materials()

func _align_world_to_spawn(target: Transform3D) -> void:
	var world_root = get_tree().get_first_node_in_group("movable_world")
	if world_root == null:
		return

	var anchor:= world_anchor.global_transform
	var offset:= anchor.affine_inverse() * target
	var inv_offset:= offset.affine_inverse()

	for obj in get_tree().get_nodes_in_group("movable_world"):
		var local = anchor.affine_inverse() * obj.global_transform
		obj.global_transform = anchor * inv_offset * local

func _reset_indicator_materials() -> void:
	for mat in indicator_materials:
		mat.albedo_color = Color(1, 1, 1, 1)

func _physics_process(delta: float) -> void:
	if current_segment == null:
		return

	var is_player = TrainManager.active_train == self

	var delta_move = speed * delta * direction
	distance_along += delta_move

	var curve = current_segment.path.curve
	var length = curve.get_baked_length()

	if distance_along > length or distance_along < 0.0:
		_transition()
		return
	
	var target_transform = current_segment.get_sample_transform(distance_along)
	
	if is_player:
		var delta_transform = previous_train_transform.affine_inverse() * target_transform
		# move_world_relative_to_player(delta_transform)
		apply_world_shift(delta_transform)
		
		world_anchor.global_transform = current_segment.get_sample_transform(distance_along)
		previous_train_transform = current_segment.get_sample_transform(distance_along)
	else:
		global_transform = target_transform
		previous_train_transform = target_transform


func apply_world_shift(delta_transform: Transform3D) -> void:
	var anchor = world_anchor.global_transform
	var inv_delta = delta_transform.affine_inverse()

	for obj in get_tree().get_nodes_in_group("movable_world"):
		var local = anchor.affine_inverse() * obj.global_transform
		obj.global_transform = anchor * inv_delta * local

func _transition():
	var exit_port = _get_exit_port()
	var options = RailGraphManager.get_connections(exit_port)

	if options.is_empty():
		speed = 0
		return
	
	var next_port = null

	if is_player_controlled:
		next_port = RailGraphManager.get_active_connection(exit_port)
	else:
		next_port = ai_choose_branch(exit_port, options)

	if next_port == null:
		speed = 0
		return
	
	_attach_to_port(next_port)

func _get_exit_port() -> Node3D:
	if direction == 1:
		return current_segment.get_node("PortB")
	else:
		return current_segment.get_node("PortA")

func _input(event):
	if TrainManager.active_train != self:
		return
	
	if event.is_action_pressed("ui_up"):
		print("Next Junction")
		_cycle_switch(1)
	if event.is_action_pressed("ui_down"):
		print("Previous Junction")
		_cycle_switch(-1)

func _cycle_switch(dir: int):
	if not can_switch():
		return
	
	var exit_port = _get_exit_port()
	var options = RailGraphManager.get_connections(exit_port)

	if options.size() <= 1:
		return

	pending_switch_index = (pending_switch_index + dir) % options.size()
	if pending_switch_index < 0:
		pending_switch_index += options.size()
	
	var selected_port = options[pending_switch_index]
	RailGraphManager.set_switch(exit_port, selected_port)

func can_switch() -> bool:
	if current_segment == null:
		return false

	var curve = current_segment.path.curve
	var length = curve.get_baked_length()

	if direction == 1:
		return distance_along < (length - switch_cutoff_distance)
	else:
		return distance_along > switch_cutoff_distance

func update_indicators(exit_port: Node3D) -> void:
	var options = RailGraphManager.get_connections(exit_port)
	if options.is_empty():
		for ind in junction_indicators:
			ind.visible = false
		return
	
	var active_port = RailGraphManager.get_active_connection(exit_port)
	var index := 0

	for i in options.size():
		var start_port = options[i]
		var port_chain = _get_lookahead_path(start_port, lookahead_steps)

		for j in port_chain.size():
			var p = port_chain[j]
			var seg = p.get_parent()
			if seg == null:
				continue
			
			_ensure_indicator(index)

			var ind = junction_indicators[index]
			var mat = indicator_materials[index]

			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

			var t := float(j) / float(max(port_chain.size() - 1, 1))

			var d = seg.path.curve.get_baked_length() / 2
			var xform = seg.get_sample_transform(d)
			ind.global_transform = xform.orthonormalized()

			ind.visible = true

			var is_active_branch = start_port == active_port

			var base_color = Color(1, 0.2, 0.2) if is_active_branch else Color(0.6, 0.6, 0.6)
			var alpha = lerp(0.9, 0.1, t)

			var target_color = Color(base_color.r, base_color.g, base_color.b, alpha)

			# var current = mat.albedo_color
			# mat.albedo_color = current.lerp(target_color, get_process_delta_time() * 8.0)
			mat.albedo_color = target_color

			index += 1
	_hide_excess(index)
	
func _ensure_indicator(i: int) -> void:
	while junction_indicators.size() <= i:
		var ind = indicator_scene.instantiate()
		get_tree().get_first_node_in_group("movable_world").add_child(ind)

		var mesh := ind.get_node_or_null("MeshInstance3D")
		var mat := StandardMaterial3D.new()

		if mesh:
			mesh.set_surface_override_material(0, mat)
		
		junction_indicators.append(ind)
		indicator_materials.append(mat)

func _hide_excess(count: int) -> void:
	for i in range(count, junction_indicators.size()):
		junction_indicators[i].visible = false

func _hide_all() -> void:
	for ind in junction_indicators:
		ind.visible = false

func _set_indicator_active(index: int) -> void:
	var mat = indicator_materials[index]
	mat.albedo_color = Color(1, 0.2, 0.2, 0.9)

func _set_indicator_inactive(index: int) -> void:
	var mat = indicator_materials[index]
	mat.albedo_color = Color(0.6, 0.6, 0.6, 0.3)

func _on_junction_changed(exit_port: Node3D) -> void:
	update_indicators(exit_port)

func _get_lookahead_path(start_port: Node3D, depth: int) -> Array[Node3D]:
	var result: Array[Node3D] = []

	var port = start_port

	for i in depth:
		if port == null:
			break

		var segment = port.get_parent()
		if segment == null:
			break

		result.append(port)

		var exit_port = _get_exit_from_segment(port)

		if exit_port == null:
			break

		var next_port = RailGraphManager.get_active_connection(exit_port)
		if next_port == null:
			var options = RailGraphManager.get_connections(exit_port)
			if options.is_empty():
				break
			next_port = options[0]

		port = next_port

	return result

func _get_exit_from_segment(port: Node3D) -> Node3D:
	var seg = port.get_parent()

	if seg == null:
		return null

	if port.name == "PortA":
		return seg.get_node("PortB")
	else:
		return seg.get_node("PortA")

func ai_choose_branch(exit_port: Node3D, options: Array) -> Node3D:
	var active = RailGraphManager.get_active_connection(exit_port)
	if active != null:
		return active
	
	return options[0]
