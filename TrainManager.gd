extends Node3D

@export var train_scene: PackedScene

@onready var track = get_node("../Track")
@onready var player = get_node("../Character")
@onready var path = track.get_node("Path3D")

var active_follow: PathFollow3D
var active_train: Node3D

var throttle_input := 0.0
var speed := 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player.train_throttle_changed.connect(Callable(self, "_on_throttle_changed"))
	spawn_train()
	call_deferred("attach_player_to_train")
	
func _on_throttle_changed(value: float) -> void:
	throttle_input = value
	
func spawn_train() -> void:
	# Create follower
	active_follow = PathFollow3D.new()
	path.add_child(active_follow)
	
	# Instance train
	active_train = train_scene.instantiate()
	active_follow.add_child(active_train)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if active_train and active_follow:
		active_train.update_movement(throttle_input, delta)
		active_follow.progress += active_train.speed * delta
		#var throttle = active_train.get_throttle_input()
		#active_train.update_movement(throttle, delta)
		#active_follow.progress += active_train.speed * delta

func attach_player_to_train() -> void:
	var seat = active_train.get_node("SeatAnchor")
	
	# Reparent player to train
	player.get_parent().remove_child(player)
	seat.add_child(player)
	
	# Reset local transform so player snaps to seat
	player.transform = Transform3D.IDENTITY

func switch_train(new_train_scene: PackedScene) -> void:
	# Remove old
	if active_train:
		active_train.queue_free()
	if active_follow:
		active_follow.queue_free()
	
	# Spawn new
	train_scene = new_train_scene
	spawn_train()
