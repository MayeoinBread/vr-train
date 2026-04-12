extends Node3D

@export var speed: float = 2.0
@export var start_port: NodePath

var current_port: Node3D
var current_segment: Node3D

var distance: float = 0.0
var direction: int = 1

var last_pos: Vector3
var active: bool = false


func _ready():
	if start_port != NodePath():
		attach_to_port(get_node(start_port))


func attach_to_port(port: Node3D) -> void:
	current_port = port
	current_segment = port.get_parent()

	var curve: Curve3D = current_segment.path.curve
	var length := curve.get_baked_length()

	# Decide entry direction based on port
	if port.name == "PortA":
		distance = 0.0
		direction = 1
	else:
		distance = length
		direction = -1

	last_pos = curve.sample_baked(distance)
	active = true


func _process(delta: float) -> void:
	if not active:
		return

	var curve: Curve3D = current_segment.path.curve
	var length := curve.get_baked_length()

	distance += speed * direction * delta

	# Move along curve
	distance = clamp(distance, 0.0, length)
	var new_pos := curve.sample_baked(distance)

	_apply_world_shift(new_pos)

	_transition()
	# # Boundary check
	# if distance <= 0.0:

	# elif distance >= length:
	# 	_transition(current_port)

func _transition() -> void:
	# Ask graph for next port
	var exit_port = _get_exit_port()
	var next_port: Node3D = RailGraphManager.resolve_next_port(exit_port)

	if next_port == null:
		active = false
		return
	
	attach_to_port(next_port)

func _apply_world_shift(new_pos: Vector3) -> void:
	var delta := new_pos - last_pos

	# VR world shift (adjust path as needed)
	var world := get_tree().get_root().get_node("WorldRoot")
	world.global_position -= delta

	last_pos = new_pos

func _get_exit_port() -> Node3D:
	if direction > 0:
		# moving forward along curve
		return current_segment.get_node("PortB")
	else:
		return current_segment.get_node("PortA")