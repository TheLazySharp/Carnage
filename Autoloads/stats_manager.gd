extends Node

var frags: int
var current_life : int
var total_drift : int
var total_car_dmg : int
@warning_ignore("unused_signal")
signal stats_updated


#MAX CAR STATS
var max_life : int = 700
var max_fuel : int = 200
var max_speed : int = 800
var display_max_speed : int = 350
var max_torque : int = 350
var max_drift : int = 4
var max_damages : int = 50
var max_dash_duration : int = 2.0 #secondes
var max_dash_damages : int = 5
var max_nitro_up : int = 100
var max_nitro_tank : int = 200


func _ready() -> void:
	frags = 0
	total_drift = 0
	total_car_dmg = 0


func unload() -> void:
	frags = 0
	current_life = 0
	total_drift = 0
	total_car_dmg = 0
	
