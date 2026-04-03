extends XROrigin3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	# TODO for future movement inside trains
	#var input_dir = Vector3.ZERO
	#
	#if Input.is_action_pressed("move_forward"):
		#input_dir.z -= 1
	#
	#translate(input_dir * delta * 2.0)
