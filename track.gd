extends Node3D

@export var start_port: Node3D

func _ready() -> void:
	RailGraphManager.initialise($Segments, $TrackConnections, start_port)
