extends Node3D

@export var min_angle := -30.0  # degrees
@export var max_angle := 30.0  # degrees

var current_angle := 0.0
var is_grabbed := false  # TODO set to false, update with VR grab


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_grabbed:
		update_from_input()
		
	rotation_degrees.x = current_angle

func update_from_input():
	# TEMP: keyboard input (replace later with VR hand)
	var input := 0.0
	if Input.is_action_pressed("ui_up"):
		input += 1.0
	if Input.is_action_pressed("ui_down"):
		input -= 1.0
	
	current_angle += input * 60.0 * get_process_delta_time()
	current_angle = clamp(current_angle, min_angle, max_angle)

func get_value() -> float:
	return inverse_lerp(min_angle, max_angle, current_angle)

func _on_hinge_hinge_moved(angle: Variant) -> void:
	current_angle = angle
