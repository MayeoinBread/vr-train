extends Node3D

@export var train_manager: Node

@onready var desktop_ui = $DebugUI_Desktop
@onready var vr_ui = $DebugUI_VR

@onready var desktop_label: Label = $DebugUI_Desktop/MarginContainer/PanelContainer/Label
@onready var vr_label: Label = $DebugUI_VR/SubViewport/Control/Panel/Label

var use_vr := false

var timer := 0.0

func ready():
	detect_mode()
	apply_mode()
	
	var quad = $DebugUI_VR/MeshInstance3D
	var viewport = $DebugUI_VR/SubViewport
	
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = viewport.get_texture()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	quad.material_override = mat

func _process(delta):
	timer += delta
	
	if not train_manager:
		return
		
	if timer > 0.1:
		var text = build_debug_text()
		desktop_label.text = text
		vr_label.text = text
		timer = 0.0

func build_debug_text() -> String:
	var tm = train_manager
	
	if not tm.current_segment:
		return "No segment"
	
	var seg = tm.current_segment
	var train = tm.train
	
	var text := ""
	
	# --- Core Info ---
	text += "Speed: %.2f\n" % train.speed
	text += "Throttle: %.2f\n" % train.throttle
	text += "Direction: %s\n" % get_direction_string(train.direction)
	text += "Segment: %s\n" % seg.name
	text += "Distance: %.2f\n" % tm.distance_along
	
	# --- Junction ---
	text += "\n-- Junction --\n"
	
	if train.direction == 1:
		text += "Next count: %d\n" % seg.next_segments.size()
		text += "Selected: %d\n" % seg.next_junction_index
	else:
		text += "Prev count: %d\n" % seg.previous_segments.size()
		text += "Selected: %d\n" % seg.previous_junction_index
	
	# --- Station ---
	text += "\n-- Station --\n"
	var station_info = tm.get_next_station_info(5)
	if station_info.station:
		text += "Next station: %s\nDistance: %.2f m" % [station_info.station.station_name, station_info.distance]
	else:
		text += "No station ahead"
	
	return text

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
