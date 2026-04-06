@tool
extends Node3D

@export var active_index: int = -1:
	set(value):
		active_index = value
		_update_visuals()

@export var light_nodes: Array[Node3D] = []

func _ready():
	_update_visuals()

func _update_visuals():
	for i in light_nodes.size():
		var light = light_nodes[i]
		if not light:
			continue
		
		light.visible = (i == active_index)

func set_direction_by_string(dir: String):
	match dir:
		"left":
			active_index = 1
		"straight":
			active_index = 0
		"right":
			active_index = 2
		_:
			active_index = -1
