extends Node3D

var speed := 0.0
var acceleration := 2.0
var max_speed := 20.0

@onready var lever = $SeatAnchor/LeverBase/LeverHandle

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func update_movement(input_throttle: float, delta: float) -> void:
	speed += input_throttle * acceleration * delta
	speed = clamp(speed, 0.0, max_speed)
	print(speed)

func get_throttle_input() -> float:
	return lever.get_value()
