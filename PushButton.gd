extends Node3D

signal pressed

@export var debounce_time: float = 0.2  # seconds
var _is_pressed: bool = false
var _timer: float = 0.0

func _process(delta):
	if _is_pressed:
		_timer -= delta
		if _timer <= 0.0:
			_is_pressed = false

func _on_interactable_area_button_button_pressed(button: Variant) -> void:
	if _is_pressed:
		return  # ignore additional presses
	_is_pressed = true
	_timer = debounce_time
	emit_signal("pressed")
