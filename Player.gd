extends Node3D

signal train_throttle_changed(throttle: float)

var seat_anchor: Node3D = null
var seat_offset: Transform3D = Transform3D.IDENTITY

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var xr_interface = XRServer.primary_interface
	if xr_interface:
		xr_interface.connect("pose_recentered", Callable(self, "_on_pose_recentered"))
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
	
	if seat_anchor:
		global_transform = seat_anchor.global_transform * seat_offset

func _on_pose_recentered():
	_reset_xr_origin()

func on_seated():
	_reset_xr_origin()

func set_seat_anchor(seat: Node3D) -> void:
	seat_anchor = seat
	seat_offset = seat.global_transform.affine_inverse() * global_transform

func _reset_xr_origin():
	if seat_anchor:
		seat_offset = seat_anchor.global_transform.affine_inverse() * global_transform
	#$XROrigin3D.transform = Transform3D.IDENTITY
