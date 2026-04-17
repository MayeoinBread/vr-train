extends Node3D

@export var port: Node3D

func _ready() -> void:
    RailGraphManager.register_spawn_point(self)