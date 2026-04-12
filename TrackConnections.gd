@tool
extends Node3D

@export var connections: Array[Dictionary] = []

@export var draw_debug_ui := false:
    set(value):
        draw_debug_ui = false
        draw_debug()

@export var debug_enabled := true
@export var sphere_size := 0.3

# func _process(_delta):
#     if Engine.is_editor_hint() and debug_enabled:
#         draw_debug()

func draw_debug():
    # clear old markers
    for c in get_children():
        c.queue_free()

    for conn in connections:
        var from_seg = get_node(conn["from_segment"])
        var to_seg = get_node(conn["to_segment"])

        var from_port = from_seg.get_node("Port" + conn["from_port"])
        var to_port = to_seg.get_node("Port" + conn["to_port"])

        var pos = (from_port.global_position + to_port.global_position) * 0.5

        var color = evaluate_connection(from_port, to_port)

        add_sphere(pos, color)

func add_sphere(pos: Vector3, color: Color):
    var mesh_instance = MeshInstance3D.new()

    var mesh = SphereMesh.new()
    mesh.radius = sphere_size
    mesh_instance.mesh = mesh

    mesh_instance.global_position = pos

    var mat = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color.a = 0.5
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

    mesh_instance.material_override = mat

    add_child(mesh_instance)

func evaluate_connection(a: Node3D, b: Node3D) -> Color:
    var distance = a.global_position.distance_to(b.global_position)

    var facing = a.global_transform.basis.z.dot(b.global_transform.basis.z)

    # position mismatch
    if distance > 0.05:
        return Color.RED

    # orientation mismatch
    if facing > -0.8:
        return Color.YELLOW

    return Color.GREEN