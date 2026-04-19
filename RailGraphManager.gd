@tool
extends Node

signal junction_changed(exit_port: Node3D)

var signal_scene: PackedScene = preload("res://FeatherSignal.tscn")
var junction_signals := {}  # exit_port -> signal instance

var junction_ordering := {}

var ports = {}  # key: "segmentA:portA"
var connections := {}  # adjacency list

var active_switches := {}
# key: Node3D (switch port or switch segment identifier)
# value: Node3D (selected next port)

# var start_port: Node3D

var reservation_intents := {}

var spawn_points: Array = []

var segments: Array = []

var track_root: Node
var connections_source: Node

func initialise(track: Node, track_connections: Node):
	track_root = track
	connections_source = track_connections
	get_segments(track_root)
	build_graph(track_root)
	apply_connections(connections_source)

	_build_junction_ordering()

	_build_signals()

func get_segments(track: Node) -> void:
	for seg in track.get_children():
		if seg.name.contains("Segment"):
			segments.append(seg)

func register_spawn_point(spawn_point: Node3D) -> void:
	if spawn_point == null:
		return
	
	if spawn_point not in spawn_points:
		spawn_points.append(spawn_point)

func get_spawn_port(index: int = 0) -> Node3D:
	if spawn_points.is_empty():
		print("No spawn points")
		return null
	
	var sp = spawn_points[index % spawn_points.size()]
	return sp.port

func _build_signals() -> void:
	for s in junction_signals.values():
		if is_instance_valid(s):
			s.queue_free()
	junction_signals.clear()

	for exit_port in connections.keys():
		var options = get_connections(exit_port)
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
	
	var target_port = resolve_next_port(exit_port)
	if target_port == null:
		return

	var branches = junction_ordering.get(exit_port, [])

	for b in branches:
		if b.port == target_port:
			m_sig.set_direction_by_string(b.label)
			break
	
	var next_segment = target_port.get_parent()
	var state = "green"
	if next_segment.occupied_by != null:
		state = "red"
	elif next_segment.reserved_by != null:
		state = "yellow"
	m_sig.set_occupancy_state(state)

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

func _build_junction_ordering():
	junction_ordering.clear()

	for exit_port in connections.keys():
		var options = connections[exit_port]
		if options.size() <= 1:
			continue

		var forward = -exit_port.global_transform.basis.z.normalized()
		forward.y = 0
		forward = forward.normalized()

		var right = forward.cross(Vector3.UP).normalized()

		var scored = []

		for target in options:
			var dir_world = _get_branch_direction(target)
			if dir_world == Vector3.ZERO:
				continue

			dir_world.y = 0
			dir_world = dir_world.normalized()

			var x = right.dot(dir_world)
			var z = forward.dot(dir_world)

			scored.append({
				"port": target,
				"x": x,
				"z": z
			})

		if scored.is_empty():
			continue

		# sort by forward alignment (MOST IMPORTANT STEP)
		scored.sort_custom(func(a, b):
			return a.z > b.z
		)

		var result = []

		# 1. best forward = straight (always)

		for score in scored:
			if score.z <= -0.8:
				result.append({
					"port": score.port,
					"label": "straight"
				})
			elif score.x <= -0.5:
				result.append({
					"port": score.port,
					"label": "right"
				})
			else:
				result.append({
					"port": score.port,
					"label": "left"
				})

		junction_ordering[exit_port] = result

func _get_junction_frame(exit_port: Node3D) -> Basis:
	var forward = -exit_port.global_transform.basis.z.normalized()
	forward.y = 0
	forward = forward.normalized()

	var right = forward.cross(Vector3.UP).normalized()
	var up = right.cross(forward).normalized()

	return Basis(right, up, forward)

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
	for port in connections[exit_port]:
		var seg = port.get_parent()
		if seg.reserved_by == self and port != target_port:
			seg.reserved_by = null
	
	active_switches[exit_port] = target_port
	junction_changed.emit(exit_port)

	_update_signal(exit_port)
	_build_junction_ordering()

func resolve_next_port(port: Node3D) -> Node3D:
	var options = connections.get(port, [])
	if options.is_empty():
		return null

	var active = active_switches.get(port, null)

	if active == null or not options.has(active):
		return options[0]

	return active

func get_connections(port: Node3D) -> Array:
	return connections.get(port, [])

func get_junction_state(exit_port: Node3D) -> Dictionary:
	var options = get_connections(exit_port)
	var active = resolve_next_port(exit_port)

	return {
		"exit_port": exit_port,
		"options": options,
		"active_port": active
	}

func _get_branch_direction(target_port: Node3D) -> Vector3:
	var segment = target_port.get_parent()
	if segment == null or segment.path == null:
		return Vector3.ZERO
	
	var curve = segment.path.curve
	if curve == null:
		return Vector3.ZERO
	
	# NOTE IF junctions get messed up in future, could be here if the curves are not too obvious
	var xform = segment.get_sample_transform(curve.get_baked_length())
	return -xform.basis.z.normalized()

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

	if dot > 0.7:
		return "straight"
	elif cross.y > 0:
		return "left"
	else:
		return "right"

func update_segment_visuals() -> void:
	for segment in track_root.get_children():
		if not segment.has_method("set_debug_owner_color"):
			continue
		
		var col := Color(1.0, 1.0, 1.0)

		if segment.occupied_by != null:
			col = segment.occupied_by.train_color
		elif segment.reserved_by != null:
			col = segment.reserved_by.train_color.darkened(0.4)
		
		segment.set_debug_owner_color(col)

func update_signals_for_segment(segment: Node3D) -> void:
	for exit_port in connections.keys():
		var target = resolve_next_port(exit_port)
		if target == null:
			continue
		
		if target.get_parent() == segment:
			_update_signal(exit_port)

func get_signal_state(exit_port: Node3D, requester: Node = null) -> String:
	var target = resolve_next_port(exit_port)
	if target == null:
		return "green"
	
	var seg = target.get_parent()
	if seg == null:
		return "green"
	
	if seg.occupied_by != null and seg.occupied_by != requester:
		return "red"

	if seg.reserved_by != null and seg.reserved_by != requester:
		return "yellow"

	return "green"

func resolve_reservations() -> void:
	var proposed := {}
	
	var trains = TrainManager.trains

	for t in trains:
		var intent = reservation_intents.get(t, [])
		for seg in intent:
			if not proposed.has(seg):
				proposed[seg] = []
			proposed[seg].append(t)
	
	var result := {}

	for seg in proposed.keys():
		var candidates = proposed[seg]
		var winner = candidates[0]

		for t in candidates:
			if t.train_priority > winner.train_priority:
				winner = t
			elif t.train_priority == winner.train_priority:
				if t.get_instance_id() < winner.get_instance_id():
					winner = t
		
		result[seg] = winner
	
	for seg in segments:
		seg.reserved_by = null
	
	for seg in result.keys():
		seg.reserved_by = result[seg]

		print(seg.name, seg.reserved_by)
	print(" ")
	reservation_intents.clear()

func submit_intent(train: Node, m_segs: Array) -> void:
	reservation_intents[train] = m_segs

func set_occupied(segment, train):
	segment.occupied_by = train
	update_signals_for_segment(segment)
