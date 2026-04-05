extends Node3D

@export var train: Node

func _on_interactable_lever_hinge_moved(angle: Variant) -> void:
	print("LeverThrottle: Angle: %.2f" % angle)
	var t = inverse_lerp(-45.0, 45.0, angle)
	var throttle = (t * 2.0) - 1.0
	train.set_throttle(throttle)
