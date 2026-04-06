extends Node3D

@export var acceleration := 2.0
@export var deceleration := 3.0
@export var max_speed := 20.0

@export var train_manager: Node = null

@onready var lever_throttle = $LeverThrottle

var throttle := 0.0  # -1 to +1

var speed := 0.0

enum Direction {
	FORWARD,
	REVERSE,
	STOPPED
}

var direction: Direction = Direction.STOPPED

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$JunctionButton.pressed.connect(_on_junction_button_pressed)

func _on_junction_button_pressed():
	if train_manager:
		train_manager.switch_junction()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if throttle > 0.0:
		speed += acceleration * throttle * delta
	elif throttle < 0.0:
		speed += deceleration * throttle * delta
	else:
		speed = move_toward(speed, 0.0, deceleration * delta)
	
	speed = clamp(speed, -max_speed, max_speed)
	
	if speed > 0.01:
		direction = Direction.FORWARD
	elif speed < -0.01:
		direction = Direction.REVERSE
	else:
		direction = Direction.STOPPED

func is_stopped() -> bool:
	return abs(speed) < 0.01

func set_throttle(value: float):
	throttle = clamp(value, -1.0, 1.0)

func get_seat_pos() -> Transform3D:
	return $SeatAnchor.global_transform
