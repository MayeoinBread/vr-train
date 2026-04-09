@tool
extends Node3D

@export var label_val := "Label":
	set(value):
		label_val = value
		_update_label()

@export var value_val := "Value":
	set(value):
		value_val = value
		_update_value()

@onready var t_label := $TextLabel
@onready var t_value := $TextValue

func _update_label():
	if t_label:
		t_label.text = label_val

func _update_value():
	if t_value:
		t_value.text = value_val
