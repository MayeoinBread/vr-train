extends Node3D

func _ready() -> void:
	RailGraphManager.initialise($Segments, $TrackConnections)
