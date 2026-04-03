extends Node3D

@export var sleeper_scene: PackedScene
@export var rail_mesh: Mesh

@onready var path: Path3D = $Path3D

@export var sleeper_spacing := 1.0
@export var rail_offset := 0.7  # Distance from center

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	build_track()

func build_track() -> void:
	var curve = path.curve
	var length = curve.get_baked_length()
	
	var distance := 0.0
	
	while distance < length:
		var transform = curve.sample_baked_with_rotation(distance)
		
		# Add sleepers
		var sleeper = sleeper_scene.instantiate()
		add_child(sleeper)
		sleeper.global_transform = transform
		
		# Rails
		create_rail_instance(transform, rail_offset)
		create_rail_instance(transform, -rail_offset)
		
		distance += sleeper_spacing

func create_rail_instance(base_transform: Transform3D, offset: float) -> void:
	var rail = MeshInstance3D.new()
	rail.mesh = rail_mesh
	add_child(rail)
	
	var right = base_transform.basis.x.normalized()
	var offset_pos = right * offset
	
	rail.global_transform = base_transform.translated(offset_pos)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
