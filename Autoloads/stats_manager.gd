extends Node

var frags: int
var current_life : int
@warning_ignore("unused_signal")
signal stats_updated

func _ready() -> void:
	frags = 0


func _process(_delta: float) -> void:
	pass


func unload() -> void:
	frags = 0
	current_life = 0
	
