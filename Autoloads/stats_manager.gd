extends Node

var frags: int
var current_life : int
var total_drift : int
var total_car_dmg : int
var total_distance : int
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
var max_dash_duration : float = 2.0 #secondes
var max_dash_damages : int = 5
var max_nitro_up : int = 20
var max_nitro_tank : int = 200

#MAX DRIFT STATS average of these stats
var max_drift_charge_speed : float = 2.0
var max_combo_step : float = 0.5
var max_drift_hit_power : float = 2.5
##  average fill of the drift stats, in percent
var max_drift_score : float = 100.0

func _ready() -> void:
	frags = 0
	total_drift = 0
	total_car_dmg = 0
	total_distance = 0
	SignalManager.distance_traveled.connect(_on_distance_traveled)


func unload() -> void:
	frags = 0
	current_life = 0
	total_drift = 0
	total_car_dmg = 0
	total_distance = 0


func _on_distance_traveled(distance_meters: int) -> void:
	total_distance += distance_meters


func get_drift_score(car : CarData, preview_part : BoostData = null) -> float:
	var total : float = 0.0
	total += _get_preview_value(car, car.drift_turn_bonus, preview_part) / max_drift
	total += _get_preview_value(car, car.drift_charge_speed, preview_part) / max_drift_charge_speed
	total += _get_preview_value(car, car.combo_step, preview_part) / max_combo_step
	total += _get_preview_value(car, car.drift_hit_power, preview_part) / max_drift_hit_power
	return max_drift_score * total / 4.0


## Value of a car stat, with the next level of the part if that part targets it
func _get_preview_value(car : CarData, stat : Statistic, preview_part : BoostData) -> float:
	if preview_part == null or !preview_part.is_car_part():
		return stat.get_value()
	for target_stat : BoostData.Target_Stats in preview_part.target_stats:
		if preview_part.get_car_stat(target_stat, car) == stat:
			return stat.preview_value(preview_part.make_part_modifier(car.get_part_level(preview_part.car_part)))
	return stat.get_value()
