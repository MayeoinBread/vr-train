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
@export var segment_frame_basis := Basis()

@export var next_entry_offsets: Array[Transform3D]
@export var previous_entry_offsets: Array[Transform3D]

var markers_forward: Array[MeshInstance3D]
var markers_backward: Array[MeshInstance3D]

var station_marker: MeshInstance3D

var occupied_by: Node = null
var reserved_by: Node = null

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

func get_sample_transform(distance: float) -> Transform3D:
	var local := path.curve.sample_baked_with_rotation(distance)
	return global_transform * Transform3D(segment_frame_basis, Vector3.ZERO) * local

func map_entry_distance(from_previous: bool, incoming_distance: float) -> float:
	var length = path.curve.get_baked_length()

	if from_previous:
		return incoming_distance
	else:
		return length - incoming_distance

func get_aligned_transform(distance: float, forward: bool) -> Transform3D:
	var length = path.curve.get_baked_length()

	var d = distance
	if not forward:
		d = length - distance

	var local := path.curve.sample_baked_with_rotation(d)
	return global_transform * local

func get_curve_start_point() -> Transform3D:
	var point0 = path.curve.sample_baked_with_rotation(0)
	return global_transform * point0

func get_curve_end_point() -> Transform3D:
	var length = path.curve.get_baked_length()
	var point1 = path.curve.sample_baked_with_rotation(length)
	return global_transform * point1

func test_curve_stuff() -> void:

	var point0 = path.curve.sample_baked_with_rotation(0)
	var point1 = path.curve.sample_baked_with_rotation(path.curve.get_baked_length())

	print("Local:")
	print("0:", point0, "1:", point1)

	point0 = global_transform * point0
	point1 = global_transform * point1

	print("Global:")
	print("0:", point0, "1:", point1)

	point0.origin.distance_to(point1.origin)

func set_debug_owner_color(col: Color) -> void:

	var mesh_parent = $TrackBuilder
	for child in mesh_parent.get_children():
		if child is MeshInstance3D:
			var mat: StandardMaterial3D = child.get_surface_override_material(0)

			if mat == null or not (mat is StandardMaterial3D):
				mat = StandardMaterial3D.new()
				child.set_surface_override_material(0, mat)
			
			mat.albedo_color = col
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func can_enter(train: Node3D) -> bool:
	if occupied_by != null and occupied_by != train:
		return false

	var other = reserved_by
	if other != null and other != train:
		if other.train_priority > train.train_priority:
			return false
		
		if other.train_priority == train.train_priority:
			return other.get_instance_id() > train.get_instance_id()
	
	return true
