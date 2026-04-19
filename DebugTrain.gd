extends Node3D

enum TrackVisualState {
	JUNCTION_PREVIEW,
	CRUISE_PREVIEW
}

var visual_state: TrackVisualState = TrackVisualState.CRUISE_PREVIEW

@export var world_anchor: Node3D
@export var spawn_point_index: int = 0

@export var is_player_controlled: bool = false

@export var train_color: Color = Color(0.2, 0.8, 1.0)
@export var train_priority: int = 0

@export var speed:= 2.0
@export var brake_speed:= 0.5
@export var accel_rate:= 1.2
@export var brake_rate:= 2.5
@export var stop_distance:= 2.0
var default_speed: float
@export var auto_start: bool = true

@export var switch_cutoff_distance := 5.0

@export var indicator_scene: PackedScene

@export var lookahead_steps := 3
@export var lookahead_reserve := 3

var active_indicator: Node3D
var junction_indicators: Array[Node3D] = []
var indicator_materials: Array[StandardMaterial3D] = []

var current_port: Node3D
var current_segment: Node3D

var distance_along: float = 0.0
var direction: int = 1

var previous_train_transform: Transform3D

func _ready() -> void:
	default_speed = speed
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
	if current_segment:
		if current_segment.occupied_by == self:
			current_segment.occupied_by = null
		if current_segment.reserved_by == self:
			current_segment.reserved_by = null
		RailGraphManager.update_signals_for_segment(current_segment)

	# update current segment to the new segment
	current_port = port
	current_segment = port.get_parent()

	# Reserve new segment for train
	current_segment.occupied_by = self
	current_segment.reserved_by = null

	RailGraphManager.update_signals_for_segment(current_segment)

	var curve: Curve3D = current_segment.path.curve
	var length := curve.get_baked_length()

	if port.name == "PortA":
		distance_along = 0.0
		direction = 1
	else:
		distance_along = length
		direction = -1

	var start_transform = current_segment.get_sample_transform(distance_along)
	
	if TrainManager.active_train == self:
		_align_world_to_spawn(start_transform)
		previous_train_transform = current_segment.get_sample_transform(distance_along)

	update_indicators(_get_exit_port())
	RailGraphManager.update_segment_visuals(RailGraphManager.track_root)

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

	if not is_player_controlled:

		var exit_port = _get_exit_port()
		var options = RailGraphManager.get_connections(exit_port)

		var next_segment = null
		var next_port = null

		if options.size() > 0:
			next_port = RailGraphManager.resolve_next_port(exit_port)
			
			if next_port != null:
				_reserve_lookahead(exit_port)
				next_segment = next_port.get_parent()
		
		var can_proceed = next_segment == null or RailGraphManager.can_enter_segment(self, next_segment)
		
		var target_speed = default_speed
		if not can_proceed:
			target_speed = 0
		else:
			var mc = current_segment.path.curve
			var ml = mc.get_baked_length()

			var dist_to_end = (
				ml - distance_along if direction == 1
				else distance_along
			)

			if dist_to_end < stop_distance:
				target_speed = brake_speed
		
		var rate = brake_rate if target_speed < speed else accel_rate
		speed = move_toward(speed, target_speed, rate * delta)

	var delta_move = speed * delta * direction
	distance_along += delta_move

	var curve = current_segment.path.curve
	var length = curve.get_baked_length()

	if distance_along > length or distance_along < 0.0:
		_transition()
		return
	
	var target_transform = current_segment.get_sample_transform(distance_along)
	
	if is_player_controlled:
		var delta_transform = previous_train_transform.affine_inverse() * target_transform
		apply_world_shift(delta_transform)
		
		world_anchor.global_transform = current_segment.get_sample_transform(distance_along)
		previous_train_transform = current_segment.get_sample_transform(distance_along)
	else:
		var anchor = world_anchor.global_transform
		global_transform = anchor * target_transform
	
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
		
	var next_port = RailGraphManager.resolve_next_port(exit_port)
	
	if next_port == null:
		speed = 0
		if not is_player_controlled:
			reparent(get_tree().get_first_node_in_group("movable_world"))
		return
	
	if not is_player_controlled:
		reparent(get_tree().get_first_node_in_group("movable_world"))
	
	var next_segment = next_port.get_parent()
	if not is_player_controlled and not RailGraphManager.can_enter_segment(self, next_segment):
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
	var cans = can_switch()
	print("CanSwitch: ", cans)
	if not cans:
		return
	
	var exit_port = _get_exit_port()
	var options = RailGraphManager.get_connections(exit_port)

	if options.size() <= 1:
		return

	var current = RailGraphManager.resolve_next_port(exit_port)
	var index = options.find(current)

	if index == -1:
		index = 0
	
	index = (index + dir) % options.size()
	if index < 0:
		index += options.size()

	var selected_port = options[index]

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
	
	var active_port = RailGraphManager.resolve_next_port(exit_port)
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
		
		var next_port = RailGraphManager.resolve_next_port(exit_port)
		if next_port == null:
			break

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

func _get_next_port(exit_port: Node3D) -> Node3D:
	return RailGraphManager.resolve_next_port(exit_port)

func _reserve_lookahead(start_port: Node3D) -> void:
	var port = start_port

	for i in lookahead_reserve:
		if port == null:
			return
		
		var options = RailGraphManager.get_connections(port)
		if options.is_empty():
			return
		
		var next_port = RailGraphManager.resolve_next_port(port)
		if next_port == null:
			return
		
		var seg = next_port.get_parent()
		if seg == null:
			return
		
		var other = seg.reserved_by
		if other != null and other != self:
			# lower priority loses
			if other.train_priority > train_priority:
				return

			# equal priority -> deterministic tie-break (instance id)
			if other.train_priority == train_priority and other.get_instance_id() < get_instance_id():
				return
		
		if seg.occupied_by != null and seg.occupied_by != self:
			return

		seg.reserved_by = self
		
		port = next_port
