extends Node3D

signal train_throttle_changed(throttle: float)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$XROrigin3D/LeftHand.input_vector2_changed.connect(Callable(self, "_on_input_vector2_changed"))
	
func _on_input_vector2_changed(action_name: String, value: Vector2) -> void:
	if action_name == "throttle":
		var throttle_input = -value.y
		if abs(throttle_input) < 0.1:
			throttle_input = 0.0
		emit_signal("train_throttle_changed", throttle_input)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# TODO temporary keyboard input
	if Input.is_action_pressed("ui_up"):
		emit_signal("train_throttle_changed", 0.4)
	if Input.is_action_pressed("ui_down"):
		emit_signal("train_throttle_changed", -0.4)
	if Input.is_action_pressed("reset_throttle"):
		emit_signal("train_throttle_changed", 0.0)
