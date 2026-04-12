@tool
extends Node3D

@export var size: float = 0.2
@export var thickness: float = 0.02
@export var forward_length: float = 0.4

@export var color: Color = Color.RED
@export var forward_color: Color = Color.GREEN

func _ready():
    rebuild()

func rebuild():
    # Clear old children
    for child in get_children():
        child.queue_free()

    # Cross axes
    add_bar(Vector3(size, 0, 0), Vector3(size * 2, thickness, thickness), color)
    add_bar(Vector3(0, size, 0), Vector3(thickness, size * 2, thickness), color)
    add_bar(Vector3(0, 0, size), Vector3(thickness, thickness, size * 2), color)

    # Forward arrow (Z+)
    add_bar(Vector3(0, 0, forward_length / 2.0), Vector3(thickness*1.2, thickness*1.2, forward_length), forward_color)

func add_bar(local_pos: Vector3, local_scale: Vector3, col: Color):
    var mesh_instance = MeshInstance3D.new()
    var box = BoxMesh.new()
    box.size = Vector3.ONE

    mesh_instance.mesh = box
    mesh_instance.position = local_pos
    mesh_instance.scale = local_scale

    var mat = StandardMaterial3D.new()
    mat.albedo_color = col
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mesh_instance.material_override = mat

    add_child(mesh_instance)