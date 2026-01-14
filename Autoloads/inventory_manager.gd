extends Node

var auto_parts : int



func _ready() -> void:
	auto_parts = 0
	
func unload():
	auto_parts = 0
