extends Node3D

@export var acceleration := 2.0
@export var deceleration := 3.0
@export var max_speed := 20.0

var speed := 0.0

enum Direction {
	FORWARD,
	REVERSE,
	STOPPED
}

var direction: Direction = Direction.STOPPED

@onready var lever = $SeatAnchor/LeverBase/LeverHandle

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func update_movement(input_throttle: float, delta: float) -> void:
	# throttle: -1 (brake) to +1 (accelerate)
	if input_throttle > 0.0:
		speed += acceleration * input_throttle * delta
	elif input_throttle < 0.0:
		speed += deceleration * input_throttle * delta
	else:
		# natural slowdown
		speed = move_toward(speed, 0.0, deceleration * delta)
	
	speed = clamp(speed, -max_speed, max_speed)
	
	if speed > 0.01:
		direction = Direction.FORWARD
	elif speed < -0.01:
		direction = Direction.REVERSE
	else:
		direction = Direction.STOPPED

func get_throttle_input() -> float:
	return lever.get_value()
