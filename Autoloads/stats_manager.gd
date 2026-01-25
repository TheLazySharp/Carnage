extends Node

#var car : CarData
var frags: int


func _ready() -> void:
	frags = 0



func _process(_delta: float) -> void:
	pass


func update_car_stats(car : CarData):
	#car = CarManager.selected_car
	if car:
		car.acceleration = car.base_acceleration + car.carbon_lvl * 5 - car.shield_lvl * 5 + car.turbo_lvl * 10
		car.max_speed = car.base_max_speed + car.engine_lvl * 10
		car.max_life = car.base_max_life + car.shield_lvl * 5 + car.tank_lvl * 10
		car.display_max_speed = car.base_display_max_speed + car.engine_lvl * 5
		car.dmg = car.base_dmg + car.shield_lvl * 5
