extends Node3D

@export var speed: float = 2.0
@export var auto_start: bool = true

@export var switch_cutoff_distance := 5.0

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
	var exit_port = _get_exit_port()
	var next_port = RailGraphManager.resolve_next_port(exit_port)

	print("EXIT:", exit_port)
	print("NEXT PORT:", next_port)

	if next_port == null:
		print("NO NEXT SEGMENT - STOPPING")
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
	
	RailGraphManager.set_switch(exit_port, options[pending_switch_index])

func can_switch() -> bool:
	var curve = current_segment.path.curve
	var length = curve.get_baked_length()

	if direction == 1:
		return distance_along < (length - switch_cutoff_distance)
	else:
		return distance_along > switch_cutoff_distance
