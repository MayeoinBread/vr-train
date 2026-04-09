extends Node3D

@export var acceleration := 2.0
@export var deceleration := 3.0
@export var max_speed := 20.0

@export var train_manager: Node = null

@onready var lever_throttle = $LeverThrottle

var throttle := 0.0  # -1 to +1
var throttle_step := 1.5

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
	$tram/SpeedScreen.label_val = "Speed:"

func _on_junction_button_pressed():
	if train_manager:
		train_manager.switch_junction()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	if throttle > 0.0:
		update_speed(delta, acceleration)
	elif throttle < 0.0:
		update_speed(delta, deceleration)
	else:
		speed = move_toward(speed, 0, deceleration * delta)
	
	speed = clamp(speed, -max_speed, max_speed)
	
	$tram/SpeedScreen.value_val = "%.2f" % speed
	
	if speed > 0.01:
		direction = Direction.FORWARD
	elif speed < -0.01:
		direction = Direction.REVERSE
	else:
		direction = Direction.STOPPED
	
	$LeverThrottle.update_throttle_visual(throttle)

func update_speed(delta: float, acc: float) -> void:
	var target_speed = throttle * max_speed
	speed = move_toward(speed, target_speed, acc * delta)

func is_stopped() -> bool:
	return abs(speed) < 0.01

func set_throttle(value: float, reset:= false):
	if reset:
		throttle = 0.0
		return
	
	throttle += value
	throttle = clamp(throttle, -1.0, 1.0)

func get_seat_pos() -> Transform3D:
	return $SeatAnchor.global_transform
