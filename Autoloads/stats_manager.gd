extends Node

var frags: int
var current_life : int
var total_drift : int
var total_car_dmg : int
@warning_ignore("unused_signal")
signal stats_updated

func _ready() -> void:
	frags = 0
	total_drift = 0
	total_car_dmg = 0


func unload() -> void:
	frags = 0
	current_life = 0
	total_drift = 0
	total_car_dmg = 0
	
