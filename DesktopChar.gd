extends Camera3D

signal train_throttle_changed(throttle: float)

func _process(delta: float) -> void:
	# TODO temporary keyboard input
	#if Input.is_action_pressed("ui_up"):
		#emit_signal("train_throttle_changed", 0.4)
	#if Input.is_action_pressed("ui_down"):
		#emit_signal("train_throttle_changed", -0.4)
	#if Input.is_action_pressed("reset_throttle"):
		#emit_signal("train_throttle_changed", 0.0)
	pass

func on_seated():
	pass

func set_seat_anchor(seat: Node3D):
	pass
