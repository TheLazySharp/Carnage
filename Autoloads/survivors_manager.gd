extends Node

var max_survivor_per_path : int = 2
var max_survivor_on_road : int = 5 #CHANGE TO 8 WHEN CREATED
var next_spawned_survivor : SurvivorData = null

var locked_survivors : Array[SurvivorData] = [] #not available survivor
var known_survivors : Array[SurvivorData] = [] #available to start a game with
var on_board_survivors : Array[SurvivorData] = [] #in the car during a game
var on_the_road_survivors : Array[SurvivorData] = [] #selected for the current game / could be saved and onboarded / picked in known and locked survivors


const BORIS = preload("uid://co2hy6ybsg7b6")
const JAVIER = preload("uid://b5ctlqm42kkmh")
const LEO = preload("uid://b6nh0gs2w1hog")
const VIKTOR = preload("uid://c4cxif75gn4yr")
const MARINA = preload("uid://d3q6e2ttbedxt")

@warning_ignore("unused_signal")
signal portrait_hovered(id : int)
@warning_ignore("unused_signal")
signal picked_up_survivor(new_survivor : SurvivorData)
@warning_ignore("unused_signal")
signal in_game_survivor_queuefree

func _ready() -> void:
	SignalManager.sandbox_mode.connect(_on_sandbox_mode)
	SignalManager.district_survivor.connect(_on_district_selected)
	locked_survivors.append(LEO)
	locked_survivors.append(VIKTOR)
	locked_survivors.append(MARINA)
	#locked_survivors.append(JAVIER)
	locked_survivors.append(BORIS)
	
	##-----------TEST-----------
	known_survivors.append(JAVIER)
	#known_survivors.append(VIKTOR)
	#known_survivors.append(BORIS)
	#known_survivors.append(LEO)
	#known_survivors.append(MARINA)

	pick_random_survivor()

func select_survivor(new_survivor : SurvivorData) -> void : 
	if known_survivors.has(new_survivor):
		on_board_survivors.append(new_survivor)

func pick_up_survivor(new_survivor : SurvivorData) -> void :
	for i in locked_survivors.size():
		if locked_survivors[i] == new_survivor and !known_survivors.has(new_survivor):
			known_survivors.append(new_survivor)
			locked_survivors.remove_at(i)
			WeaponsManager.equip_weapon(new_survivor.weapon)
			break

func unload() -> void :
	on_board_survivors.clear()

func _on_sandbox_mode() -> void : 
	known_survivors.clear()
	locked_survivors.clear()
	on_the_road_survivors.clear()
	known_survivors.append(JAVIER)
	known_survivors.append(VIKTOR)
	known_survivors.append(BORIS)
	known_survivors.append(LEO)
	known_survivors.append(MARINA)
	print("sandbox mode survivor")


func pick_random_survivor() -> void:
	if locked_survivors.is_empty():
		push_warning("unknown survivor is empty")
		return
	locked_survivors.shuffle()
	for i in max_survivor_on_road - 1:
		on_the_road_survivors.append(locked_survivors[i])
	
	#print(on_the_road_survivors)

func _on_district_selected(next_survivor : SurvivorData) -> void:
	next_spawned_survivor = next_survivor
