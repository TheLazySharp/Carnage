extends Node

var frags: int
var current_life : int
signal stats_updated

func _ready() -> void:
	frags = 0



func _process(_delta: float) -> void:
	pass


func update_car_stats(car : CarData) -> void:
	if car:
		#LuckyCharmsManager.update_lucky_charms_bonus()
		car.acceleration = roundi((car.base_acceleration + car.carbon_lvl * 5 - car.shield_lvl * 5 + car.turbo_lvl * 10) * LuckyCharmsManager.acceleration_bonus)
		car.max_speed = roundi((car.base_max_speed + car.engine_lvl * 10) * LuckyCharmsManager.max_speed_bonus)
		car.max_life = roundi((car.base_max_life + car.shield_lvl * 5 + car.tank_lvl * 10) * LuckyCharmsManager.life_bonus)
		car.display_max_speed = roundi(car.base_display_max_speed + car.engine_lvl * 5)
		car.dmg = roundi((car.base_dmg + car.shield_lvl * 5) * LuckyCharmsManager.damages_bonus)
		car.dash_duration = (car.base_dash_duration + car.nitro_lvl * 0.1) * LuckyCharmsManager.nitro_bonus
		car.nitro_up = roundi((car.base_nitro_up + car.wheels_lvl) * LuckyCharmsManager.tires_bonus)
		car.dash_dmg_bonus = (car.base_dash_dmg_bonus + car.bumper_lvl * 0.1) * LuckyCharmsManager.dash_damages_bonus
		car.collect_radius =(car.base_collect_radius) * LuckyCharmsManager.magnetism_bonus
		emit_signal("stats_updated")

func unload() -> void:
	frags = 0
	current_life = 0
	
