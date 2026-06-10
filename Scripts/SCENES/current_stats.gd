extends Control

@onready var duration_stat_value: Label = $EndGameStats/Duration/StatValue
@onready var distance_stat_value: Label = $EndGameStats/Distance/StatValue
@onready var drift_stat_value: Label = $EndGameStats/Drift/StatValue
@onready var kills_stat_value: Label = $EndGameStats/Enemies/StatValue
@onready var dollar_stat_value: Label = $EndGameStats/Dollars/StatValue
@onready var total_dmg_stat_value: Label = $EndGameStats/Damages/StatValue
@onready var total_dps: Label = $EndGameStats/Damages/Dps
@onready var car_dmg_stat_value: Label = $WeaponsStats/Car/StatValue
@onready var car_dps: Label = $WeaponsStats/Car/Dps

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	duration_stat_value.text = str(snappedf(TimeManager.active_time,0.01))
	#distance_stat_value.text = "TBD"
	drift_stat_value.text = str(StatsManager.total_drift)
	kills_stat_value.text = str(StatsManager.frags)
	#dollar_stat_value.text = "TBD"
	total_dmg_stat_value.text = str(WeaponsManager.get_total_game_dmg() + StatsManager.total_car_dmg)
	total_dps.text = "( " + str(snappedf((WeaponsManager.get_total_game_dmg() + StatsManager.total_car_dmg) / TimeManager.active_time,0.01)) + " dps )"
	car_dmg_stat_value.text = str(StatsManager.total_car_dmg)
	car_dps.text = "( " + str(snappedf(StatsManager.total_car_dmg / TimeManager.active_time,0.01)) + " dps )"


func _on_game_paused(game_paused : bool) -> void : 
	if game_paused:
		duration_stat_value.text = str(snappedf(TimeManager.active_time,0.01))
		#distance_stat_value.text = "TBD"
		drift_stat_value.text = str(StatsManager.total_drift)
		kills_stat_value.text = str(StatsManager.frags)
		#dollar_stat_value.text = "TBD"
		total_dmg_stat_value.text = str(WeaponsManager.get_total_game_dmg() + StatsManager.total_car_dmg)
		total_dps.text = "( " + str(snappedf((WeaponsManager.get_total_game_dmg() + StatsManager.total_car_dmg) / TimeManager.active_time,0.01)) + " dps )"
		car_dmg_stat_value.text = str(StatsManager.total_car_dmg)
		car_dps.text = "( " + str(snappedf(StatsManager.total_car_dmg / TimeManager.active_time,0.01)) + " dps )"
		
