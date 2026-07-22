extends Node

var max_survivor_per_path : int = 2
var max_survivor_on_road : int = 4 #CHANGE TO 8 WHEN CREATED
var next_spawned_survivor : SurvivorData = null

var unknown_survivors : Array[SurvivorData] = []
var known_survivors : Array[SurvivorData] = []
var on_board_survivors : Array[SurvivorData] = []
var on_the_road_survivors : Array[SurvivorData] = []


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
	SignalManager.arena_survivor.connect(_on_arena_selected)
	unknown_survivors.append(LEO)
	unknown_survivors.append(VIKTOR)
	unknown_survivors.append(MARINA)
	#unknown_survivors.append(JAVIER)
	unknown_survivors.append(BORIS)
	
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
	for i in unknown_survivors.size():
		if unknown_survivors[i] == new_survivor and !known_survivors.has(new_survivor):
			known_survivors.append(new_survivor)
			unknown_survivors.remove_at(i)
			WeaponsManager.equip_weapon(new_survivor.weapon)
			break

func unload() -> void :
	on_board_survivors.clear()

func _on_sandbox_mode() -> void : 
	known_survivors.clear()
	unknown_survivors.clear()
	known_survivors.append(JAVIER)
	known_survivors.append(VIKTOR)
	known_survivors.append(BORIS)
	known_survivors.append(LEO)
	known_survivors.append(MARINA)
	print("sandbox mode survivor")


func pick_random_survivor() -> void:
	if unknown_survivors.is_empty():
		push_warning("unknown survivor is empty")
		return
	unknown_survivors.shuffle()
	for i in max_survivor_on_road - 1:
		on_the_road_survivors.append(unknown_survivors[i])

func _on_arena_selected(next_survivor : SurvivorData) -> void:
	next_spawned_survivor = next_survivor
