extends Node3D

@onready var train_follow = $Path3D/TrainFollow

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func get_train_follow():
	return $Path3D/TrainFollow
