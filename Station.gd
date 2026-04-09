@tool
extends Node3D

@export var stop_distance := 10.0:  # From start of station
	set(value):
		stop_distance = value
		_update_stop_marker()
		_set_stop_sign()
		
@export var station_name := "Unnamed Station":
	set(value):
		station_name = value
		set_station_name()

@export var stop_tolerance := 1.0

@onready var stop_sign := $StopSignal
@onready var station_label := $StationSign/Label3D

func _ready():
	set_station_name()

func _update_stop_marker():
	if not Engine.is_editor_hint():
		return
	
	var segment = get_parent()
	if segment and segment.has_method("draw_station_marker"):
		segment.draw_station_marker()

func _set_stop_sign():
	if not stop_sign:
		return
		
	var station_origin = global_transform
	
	var offset_z = station_origin.basis.z * -stop_distance
	var offset_x = station_origin.basis.x * -2.0
	station_origin.origin += offset_z
	station_origin.origin += offset_x
	stop_sign.global_transform = station_origin

func set_station_name() -> void:
	if station_label:
		station_label.text = station_name

func is_stopped_at_station(train_distance: float) -> bool:
	return abs(train_distance - stop_distance) <= stop_tolerance
