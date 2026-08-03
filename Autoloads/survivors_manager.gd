extends Node

var max_survivor_per_path : int = 2
var max_survivor_on_road : int = 5 #CHANGE TO 8 WHEN CREATED
var next_spawned_survivor : SurvivorData = null
var next_survivor_to_unlock : SurvivorData = null

var locked_survivors : Array[SurvivorData] = [] #not available survivor
var known_survivors : Array[SurvivorData] = [] #available to start a game with
var on_board_survivors : Array[SurvivorData] = [] #in the car during a game
var on_the_road_survivors : Array[SurvivorData] = [] #selected for the current game / could be saved and onboarded / picked in known and locked survivors
var survivors_pool : Array[SurvivorData] = [] #contains all the survivor that can be encountered in game : known + locked


const ALL_SURVIVORS : Array = [
	preload("uid://co2hy6ybsg7b6"), #BORIS
	preload("uid://b5ctlqm42kkmh"), #JAVIER
	preload("uid://b6nh0gs2w1hog"), #LEO
	preload("uid://c4cxif75gn4yr"), #VIKTOR
	preload("uid://d3q6e2ttbedxt"), #MARINA
]


@warning_ignore("unused_signal")
signal portrait_hovered(id : int)
@warning_ignore("unused_signal")
signal picked_up_survivor(new_survivor : SurvivorData)
@warning_ignore("unused_signal")
signal in_game_survivor_queuefree

func _ready() -> void:
	SignalManager.sandbox_mode.connect(_on_sandbox_mode)
	SignalManager.district_survivor.connect(_on_district_selected)

	
	load_known_survivors()
	load_survivors_pool()
	#load_unknown_survivors()

func select_survivor(new_survivor : SurvivorData) -> void : 
	if survivors_pool.has(new_survivor):
		on_board_survivors.append(new_survivor)
		survivors_pool.erase(new_survivor)
		load_on_road_survivors()
		

func _on_survivor_picked_up(new_survivor : SurvivorData) -> void :
	if locked_survivors.has(new_survivor):
		known_survivors.append(new_survivor)
		locked_survivors.erase(new_survivor)
	WeaponsManager.equip_weapon(new_survivor.weapon)
	on_the_road_survivors.erase(new_survivor)
	on_board_survivors.append(new_survivor)
	

func unload() -> void :
	known_survivors.clear()
	locked_survivors.clear()
	survivors_pool.clear()
	on_the_road_survivors.clear()
	on_board_survivors.clear()
	load_known_survivors()
	load_survivors_pool()

func _on_sandbox_mode() -> void : 
	known_survivors.clear()
	locked_survivors.clear()
	on_the_road_survivors.clear()
	load_known_survivors()
	print("sandbox mode survivor")


func load_on_road_survivors() -> void:
	if survivors_pool.is_empty():
		push_warning("unknown survivor is empty")
		return
	survivors_pool.shuffle()
	for i in max_survivor_on_road - 1:
		on_the_road_survivors.append(survivors_pool[i])
	print("on the road : ",on_the_road_survivors)
	print("pool: ",survivors_pool)
	

func _on_district_selected(next_survivor : SurvivorData) -> void:
	next_spawned_survivor = next_survivor
	

func load_known_survivors() -> void : 
	for known_survivor : SurvivorData in ALL_SURVIVORS:
		known_survivors.append(known_survivor)

func load_survivors_pool() -> void : 
	for survivor : SurvivorData in known_survivors:
		survivors_pool.append(survivor)
	if next_survivor_to_unlock:
		survivors_pool.append(next_survivor_to_unlock)
