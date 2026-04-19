extends Node3D

var segments: Array = []

func _ready() -> void:
	RailGraphManager.initialise($Segments, $TrackConnections)
	
	for seg in $Segments.get_children():
		if seg.name.contains("Segment"):
			segments.append(seg)

func print_segment_reservations():
	print("Reservations:")
	for seg in segments:
		if seg.reserved_by != null:
			print(seg.name, ": ", seg.reserved_by.train_priority)
		elif seg.occupied_by != null:
			print(seg.name, ": *", seg.occupied_by.train_priority)
		else:
			print(seg.name, ": -")
