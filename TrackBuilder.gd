@tool
extends Node3D

@export var path: Path3D
@export var sleeper_spacing := 1.0
@export var rail_offset := 0.75  # half gauge (distance from center)
@export var sleeper_width := 2.6
@export var sleeper_length := 0.25

@export var regenerate := false:
	set(value):
		print(value)
		regenerate = false
		generate_track()
		
var is_dirty := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	generate_track()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_dirty:
		generate_track()
		is_dirty = false

func clear_track():
	for child in get_children():
		child.queue_free()

func generate_track() -> void:
	if not path:
		return
	
	clear_track()
	
	var curve = path.curve
	var length = curve.get_baked_length()
	
	var rail_distance := sleeper_spacing * 0.5
	while rail_distance < length:
		var m_transform = curve.sample_baked_with_rotation(rail_distance)
		place_rail(m_transform)
		rail_distance += sleeper_spacing
	
	var sleeper_distance := 0.0
	while sleeper_distance < length:
		var m_transform = curve.sample_baked_with_rotation(sleeper_distance)
		place_sleeper(m_transform)
		sleeper_distance += sleeper_spacing
		
func place_sleeper(transform: Transform3D):
	var sleeper = MeshInstance3D.new()
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(sleeper_width, 0.125, sleeper_length)
	sleeper.mesh = mesh
	
	sleeper.transform = transform
	
	add_child(sleeper)

func place_rail(transform: Transform3D):
	var right = transform.basis.x.normalized()
	
	var left_transform = transform
	var right_transform = transform
	
	left_transform.origin -= right * rail_offset
	right_transform.origin += right * rail_offset
	
	create_rail_segment(left_transform)
	create_rail_segment(right_transform)

func create_rail_segment(t: Transform3D):
	var rail = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, sleeper_spacing)
	
	rail.mesh = mesh
	rail.transform = t
	
	add_child(rail)


func _on_path_3d_curve_changed() -> void:
	is_dirty = true
