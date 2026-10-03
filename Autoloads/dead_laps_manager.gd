extends Node

var car : CarData
var player : SurvivorData

var rng : RandomNumberGenerator = RandomNumberGenerator.new()
var unplugged_implants : int = 0
var total_implants : int = 3

var toll_blood_cost : int = 10
var total_laps : int = 7
var max_pit_stops : int = 3
var toll_ratio : int = 10

signal toll_blood_cost_updated(new_toll_blood_cost : int)
@warning_ignore("unused_signal")
signal new_race_implants_set
var selected_race : RaceData


var all_races : Array[RaceData] = []
var implants_target_types : Array[ImplantsManager.TYPES] = []
var implants_target_values : Array[int] = []


const RACE_UIDS : Array[String] = [
	"uid://da6uqagea2gfk", #laps kill weap dmg
	"uid://r2tvaksc8ujq", #drift kill cardmg
	"uid://w3r6ehbhuiv3", #sacrifice kill weapdmg
	"uid://fb1aitkron1n", #blood loss drift distance
	"uid://buuqx3bkykxbx", #blood absorbed weapdmg distance
	]


func _ready() -> void:
	rng.randomize()
	SignalManager.lap_completed.connect(_on_lap_completed)
	SignalManager.loading_screen_closed.connect(_new_race_to_set)
	SignalManager.implant_unplugged.connect(_on_implant_unplugged)
	load_races()

func load_races() -> void : 
	for uid : String in RACE_UIDS:
		all_races.append(load(uid) as RaceData)

func pick_races() -> RaceData:
	var race_idx : int = rng.randi_range(0,all_races.size()-1)
	return all_races[race_idx]

func _new_race_to_set() -> void : 
	selected_race = pick_races()
	set_implants(selected_race)

func set_implants(p_race : RaceData) -> void : 
	if !p_race:
		print("[dead laps manager] no selected racedata")
		return
	for i in p_race.implants.size():
		implants_target_types.append(p_race.implants[i].type)
		
		var rng_value : int = rng.randi_range(p_race.implants[i].target_min,p_race.implants[i].target_max)
		implants_target_values.append(rng_value)
	SignalManager.emit_signal("new_race_implants_set")

func _on_lap_completed(current_lap : int) -> void : 
	SignalManager.emit_signal("blood_consummed",toll_blood_cost)
	SignalManager.emit_signal("car_blood_loss",toll_blood_cost)
	if current_lap == total_laps :
		print("[deadlapsmanager] WIN")
		return
	update_toll_cost(current_lap)

func update_toll_cost(lap : int) -> void:
	toll_blood_cost += lap * toll_ratio
	emit_signal("toll_blood_cost_updated",toll_blood_cost)

func unload() -> void : 
	all_races.clear()
	implants_target_types.clear()
	implants_target_values.clear()

func _on_implant_unplugged() -> void : 
	if unplugged_implants < total_implants:
		unplugged_implants += 1
		if unplugged_implants == total_implants:
			SceneManager.load_level(SceneManager.SCENES.DEAD_LAPS_WIN)
