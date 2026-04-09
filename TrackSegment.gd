@tool
extends Node3D

@export var path: Path3D

# Connections
# First element should be the default path
@export var next_segments: Array[Node]
@export var next_directions: Array[String]
@export var previous_segments: Array[Node]
@export var previous_directions: Array[String]
@export var next_junction_index: int = 0
@export var previous_junction_index: int = 0
@export var feather_signal: NodePath
@export var station: Node

@export var junction_commit_distance := 5.0

var markers_forward: Array[MeshInstance3D]
var markers_backward: Array[MeshInstance3D]

var station_marker: MeshInstance3D

# Optional metadata
@export var speed_limit := 20
@export var is_station := false
@export var is_switch := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Engine.is_editor_hint():
		if path and path.curve:
			path.curve = path.curve.duplicate()
	
	if station:
		draw_station_marker()

func can_switch_junction(direction: int) -> bool:
	if direction == 1:
		return is_switch and next_segments.size() > 1
	if direction == -1:
		return is_switch and previous_segments.size() > 1
	return false

func switch_junction(direction: int):
	if direction == 1:
		next_junction_index = (next_junction_index + 1) % next_segments.size()
		update_signal(1)
	elif direction == -1:
		previous_junction_index = (previous_junction_index + 1) % previous_segments.size()
		update_signal(-1)

func update_signal(direction: int):
	if not feather_signal:
		return
	
	var sig = get_node_or_null(feather_signal)
	if not sig:
		return
	
	if direction == 1:
		if next_segments.size() <= 1:
			sig.set_direction_by_string("")
		else:
			sig.set_direction_by_string(next_directions[next_junction_index])
	elif direction == -1:
		if previous_segments.size() <= 1:
			sig.set_direction_by_string("")
		else:
			sig.set_direction_by_string(previous_directions[previous_junction_index])

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

func draw_station_marker():
	var stop_transform = path.curve.sample_baked_with_rotation(station.stop_distance)
	var offset = stop_transform.basis.y * 0.5
	stop_transform.origin += offset
	var local_t = path.global_transform * stop_transform
	
	if not station_marker:
		station_marker = MeshInstance3D.new()
		var mesh = SphereMesh.new()
		mesh.radius = 0.5
		station_marker.mesh = mesh
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.5, 0.5, 0.5)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material = mat
		
		add_child(station_marker)
	
	if station_marker:
		station_marker.global_transform = local_t

func is_train_stopped_at_station(train_distance: float) -> bool:
	if not station:
		return false
	
	return station.is_stopped_at_station(train_distance)
