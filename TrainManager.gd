extends Node

var trains: Array = []
var active_train = null

signal active_train_changed(train)

func register_train(train: Node) -> void:
	if train in trains:
		return
	
	trains.append(train)
	
	if active_train == null and train.is_player_controlled:
		set_active_train(train)

func unregister_train(train: Node) -> void:
	trains.erase(train)

	if active_train == train:
		active_train = null
		active_train_changed.emit(null)

func set_active_train(train: Node) -> void:
	if active_train == train:
		return

	active_train = train
	active_train_changed.emit(train)
