extends Node3D

@export var speed: float = 2.0
@export var auto_start: bool = true

@export var switch_cutoff_distance := 5.0

@export var indicator_scene: PackedScene

var active_indicator: Node3D
var junction_indicators: Array[Node3D] = []
var indicator_materials: Array[StandardMaterial3D] = []

var current_port: Node3D
var current_segment: Node3D

var distance_along: float = 0.0
var direction: int = 1

# var last_pos: Vector3
var previous_train_transform: Transform3D
var active: bool = false

var pending_switch_index: int = 0

func _ready() -> void:
	if auto_start:
		reset()
	
	RailGraphManager.junction_changed.connect(_on_junction_changed)

func reset() -> void:
	var port = RailGraphManager.start_port
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

	previous_train_transform = current_segment.get_sample_transform(distance_along)
	active = true
	
	update_junction_indicators(_get_exit_port())

func _physics_process(delta: float) -> void:
	if not active:
		return
	
	var delta_move = speed * delta * direction
	distance_along += delta_move

	var curve = current_segment.path.curve
	var length = curve.get_baked_length()

	if distance_along > length or distance_along < 0.0:
		_transition()
		return
	
	var target_transform = current_segment.get_sample_transform(distance_along)
	var delta_transform = previous_train_transform.affine_inverse() * target_transform
	move_world_relative_to_player(delta_transform)

	previous_train_transform = current_segment.get_sample_transform(distance_along)

func move_world_relative_to_player(delta_transform: Transform3D) -> void:
	var inv_delta = delta_transform.affine_inverse()
	var player_inv := global_transform.affine_inverse()
	var base := global_transform
	
	for obj in get_tree().get_nodes_in_group("movable_world"):
		var local_offset = player_inv * obj.global_transform
		obj.global_transform = base * inv_delta * local_offset

func _transition():
	var next_port = RailGraphManager.get_active_connection(_get_exit_port())

	if next_port == null:
		active = false
		speed = 0
		return
	
	_attach_to_port(next_port)

func _get_exit_port() -> Node3D:
	if direction == 1:
		return current_segment.get_node("PortB")
	else:
		return current_segment.get_node("PortA")

func _input(event):
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
	var curve = current_segment.path.curve
	var length = curve.get_baked_length()

	if direction == 1:
		return distance_along < (length - switch_cutoff_distance)
	else:
		return distance_along > switch_cutoff_distance

func update_junction_indicators(exit_port: Node3D) -> void:
	var options = RailGraphManager.get_connections(exit_port)
	var active_port = RailGraphManager.get_active_connection(exit_port)

	if options.is_empty() or options.size() <= 1:
		for ind in junction_indicators:
			ind.visible = false
		return

	while junction_indicators.size() < options.size():
		var ind = indicator_scene.instantiate()
		get_tree().get_first_node_in_group("movable_world").add_child(ind)

		var mesh := ind.get_node_or_null("MeshInstance3D")
		var mat := StandardMaterial3D.new()

		if mesh:
			mesh.set_surface_override_material(0, mat)
		
		junction_indicators.append(ind)
		indicator_materials.append(mat)
	
	for i in range(options.size()):
		var port = options[i]
		var segment = port.get_parent()
		var ind = junction_indicators[i]

		if not segment:
			ind.visible = false
			continue
	
		var d := 8.0
		var xform = segment.get_sample_transform(d)
		ind.global_transform = xform.orthonormalized()
		ind.visible = true

		if port == active_port:
			_set_indicator_active(i)
		else:
			_set_indicator_inactive(i)
	
	for i in range(options.size(), junction_indicators.size()):
		junction_indicators[i].visible = false

func _set_indicator_active(index: int) -> void:
	var mat = indicator_materials[index]
	mat.albedo_color = Color(1, 0.2, 0.2, 0.9)

func _set_indicator_inactive(index: int) -> void:
	var mat = indicator_materials[index]
	mat.albedo_color = Color(0.6, 0.6, 0.6, 0.3)

func _on_junction_changed(exit_port: Node3D) -> void:
	update_junction_indicators(exit_port)
