extends Node

var frags: int


func _ready() -> void:
	frags = 0



func _process(_delta: float) -> void:
	pass


func update_car_stats(car : CarData) -> void:
	if car:
		car.acceleration = car.base_acceleration + car.carbon_lvl * 5 - car.shield_lvl * 5 + car.turbo_lvl * 10
		car.max_speed = car.base_max_speed + car.engine_lvl * 10
		car.max_life = car.base_max_life + car.shield_lvl * 5 + car.tank_lvl * 10
		car.display_max_speed = car.base_display_max_speed + car.engine_lvl * 5
		car.dmg = car.base_dmg + car.shield_lvl * 5
		car.boost_duration = car.base_boost_duration + car.nos_lvl * 0.1
		if car.front_gear != null:
			car.dmg_boost = car.front_gear.dmg
		else: 
			car.dmg_boost = car.base_dmg_boost 
			

func unload() -> void:
	frags = 0
	
