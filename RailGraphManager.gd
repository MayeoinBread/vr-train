@tool
extends Node

signal junction_changed(exit_port: Node3D)

var signal_scene: PackedScene = preload("res://FeatherSignal.tscn")
var junction_signals := {}  # exit_port -> signal instance

var ports = {}  # key: "segmentA:portA"
var connections := {}  # adjacency list

var active_switches := {}
# key: Node3D (switch port or switch segment identifier)
# value: Node3D (selected next port)

var start_port: Node3D

var track_root: Node
var connections_source: Node

func get_default_start_port() -> Node3D:
	for port in connections.keys():
		return port
	
	return null

func _ready() -> void:
	print("REady")

func initialise(track: Node, track_connections: Node, start_node: Node3D):
	print("Initialise")
	track_root = track
	connections_source = track_connections
	build_graph(track_root)
	apply_connections(connections_source)
	start_port = start_node

	_build_signals()

func _build_signals() -> void:
	print("BUILD SIGNALS")
	for s in junction_signals.values():
		if is_instance_valid(s):
			s.queue_free()
	junction_signals.clear()

	print("FOREACH")

	print(connections.keys())

	for exit_port in connections.keys():
		var options = get_connections(exit_port)
		print("PORT: ", exit_port, "OPTIONS: ", options.size())
		if options.size() <= 1:
			continue
		
		var exit_forward = exit_port.global_transform.basis.z.normalized()

		var m_sig = signal_scene.instantiate()
		track_root.add_child(m_sig)

		m_sig.global_position = exit_port.global_position

		# align signal to track forward direction
		m_sig.look_at(m_sig.global_position + exit_forward, Vector3.UP)

		junction_signals[exit_port] = m_sig

		_update_signal(exit_port)
	
func _update_signal(exit_port: Node3D) -> void:
	var m_sig = junction_signals.get(exit_port)
	if m_sig == null:
		return
	
	var target_port = get_active_connection(exit_port)
	if target_port == null:
		return
	
	var dir_label = _get_direction_label(exit_port, target_port)
	m_sig.set_direction_by_string(dir_label)

func build_graph(track: Node):
	ports.clear()
	connections.clear()

	for segment in track.get_children():
		if not segment.has_node("PortA"):
			continue
		
		register_port(segment, "A")
		register_port(segment, "B")

func register_port(segment, port_name: String) -> void:
	var port = segment.get_node("Port" + port_name)
	var key = segment.name + ":Port" + port_name

	ports[key] = {
		"segment": segment,
		"node": port
	}

func apply_connections(track_connections):
	for c in track_connections.connections:
		var from_segment = track_root.get_node(c["from_segment"])
		var to_segment = track_root.get_node(c["to_segment"])

		var from_port = from_segment.get_node("Port" + c["from_port"])
		var to_port = to_segment.get_node("Port" + c["to_port"])

		if is_valid_connection(from_port, to_port):
			add_connection(from_port, to_port)
		else:
			var from_key = from_segment.name + ":Port" + c["from_port"]
			var to_key = to_segment.name + ":Port" + c["to_port"]
			push_warning("Invalid track connection ignored", from_key, ":", to_key)

func add_connection(from_port: Node3D, to_port: Node3D) -> void:
	if not connections.has(from_port):
		connections[from_port] = []
	
	connections[from_port].append(to_port)

func is_valid_connection(from_port, to_port) -> bool:
	if from_port == null:
		print("INVALID: from_port is null")
		return false
	
	if to_port == null:
		print("INVALID: to_port is null")
		return false
	
	if from_port == to_port:
		print("INVALID: from_port is same as to_port")
		return false
	
	var ok = true

	var dist = from_port.global_position.distance_to(to_port.global_position)
	if dist > 0.1:
		print("INVALID: distance =", dist)
		ok = false

	# NOTE: alternate with tangent consistency instead of port basis
	# var a_tangent = from_port.global_transform.basis.z.normalized()
	# var b_tangent = to_port.global_transform.basis.z.normalized()

	# if a_tangent.dot(b_tangent) > -0.7:
	#     return false

	var facing = from_port.global_transform.basis.z.dot(to_port.global_transform.basis.z)
	if facing > -0.7:
		print("INVALID: facing =", facing)
		ok = false

	return ok

func set_switch(exit_port: Node3D, target_port: Node3D) -> void:
	active_switches[exit_port] = target_port
	junction_changed.emit(exit_port)

	_update_signal(exit_port)

func get_active_connection(exit_port: Node3D) -> Node3D:
	if exit_port in active_switches:
		return active_switches[exit_port]
	
	var options = get_connections(exit_port)
	if options.is_empty():
		return null
	
	return options[0]  # default fallback

func resolve_next_port(port) -> Node3D:
	var options = connections.get(port, [])
	if options.is_empty():
		return null

	if active_switches.has(port):
		return active_switches[port]
	
	return options[0]

func get_connections(port: Node3D) -> Array:
	return connections.get(port, [])

func get_junction_state(exit_port: Node3D) -> Dictionary:
	var options = get_connections(exit_port)
	var active = get_active_connection(exit_port)

	return {
		"exit_port": exit_port,
		"options": options,
		"active_port": active
	}

func _get_direction_label(exit_port: Node3D, target_port: Node3D) -> String:
	var forward = -exit_port.global_transform.basis.z.normalized()

	var segment = target_port.get_parent()
	if segment == null or segment.path == null:
		return "straight"
	
	var curve = segment.path.curve
	if curve == null:
		return "straight"
	
	var xform = segment.get_sample_transform(curve.get_baked_length())
	var dir = xform.basis.z.normalized()

	var dot = forward.dot(dir)
	var cross = forward.cross(dir)

	print(segment)
	print(dot)
	print(cross)
	print("")

	if dot > 0.7:
		return "straight"
	elif cross.y > 0:
		return "left"
	else:
		return "right"
