extends Node3D

@onready var desktop_ui = $DebugUI_Desktop
@onready var vr_ui = $DebugUI_VR

@onready var desktop_label: Label = $DebugUI_Desktop/MarginContainer/PanelContainer/Label
@onready var vr_label: Label = $DebugUI_VR/SubViewport/Control/Label

var data_source: Node = null

var use_vr := false

var timer := 0.0

func _ready():
	detect_mode()
	apply_mode()

func _process(delta):
	timer += delta
	
	if not data_source:
		return
	
	if timer > 0.1:
		var text = data_source.build_debug_text()
		desktop_label.text = text
		vr_label.text = text
		timer = 0.0
		
func set_data_source(source):
	data_source = source

func get_direction_string(dir):
	match dir:
		0: return "Forward"
		1: return "Reverse"
		2: return "Stopped"
	return "Unknown"

func detect_mode():
	var xr = XRServer.primary_interface
	use_vr = xr != null and xr.is_initialized()
	print("Use VR UI: %s" % use_vr)

func apply_mode():
	desktop_ui.visible = not use_vr
	vr_ui.visible = use_vr
