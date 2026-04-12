@tool
extends Node

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

func initialise(track: Node, track_connections: Node, start_node: Node3D):
	track_root = track
	connections_source = track_connections
	build_graph(track_root)
	apply_connections(connections_source)
	print(ports)
	print(connections)
	start_port = start_node

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

func set_switch(port: Node3D, selected_next: Node3D) -> void:
	active_switches[port] = selected_next

func resolve_next_port(port) -> Node3D:
	var options = connections.get(port, [])
	if options.is_empty():
		return null

	if active_switches.has(port):
		return active_switches[port]
	
	return options[0]

func get_connections(port: Node3D) -> Array:
	return connections.get(port, [])
