@tool
extends Node3D

@export var path: Path3D

# Connections
# First element should be the default path
@export var next_segments: Array[Node]
@export var previous_segments: Array[Node]
@export var next_junction_index: int = 0
@export var previous_junction_index: int = 0
@export var station: Node

@export var junction_commit_distance := 5.0

var markers_forward: Array[MeshInstance3D]
var markers_backward: Array[MeshInstance3D]

# Optional metadata
@export var speed_limit := 20
@export var is_station := false
@export var is_switch := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Engine.is_editor_hint():
		if path and path.curve:
			path.curve = path.curve.duplicate()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func get_next_segment(index: int) -> Node3D:
	if index >= next_segments.size():
		return null
	return next_segments[index]

func get_previous_segment(index: int) -> Node3D:
	if index >= previous_segments.size():
		return null
	return previous_segments[index]

func get_point_on_curve(distance: float) -> Transform3D:
	var local = path.curve.sample_baked_with_rotation(distance)
	return global_transform * local
	
func get_station():
	return station
