extends Node

var unknown_survivors : Array[SurvivorData] = []
var known_survivors : Array[SurvivorData] = []
var on_board_survivors : Array[SurvivorData] = []


const BORIS = preload("uid://co2hy6ybsg7b6")
const JAVIER = preload("uid://b5ctlqm42kkmh")
const LEO = preload("uid://b6nh0gs2w1hog")
const VIKTOR = preload("uid://c4cxif75gn4yr")

@warning_ignore("unused_signal")
signal portrait_hovered(id : int)
@warning_ignore("unused_signal")
signal picked_up_survivor(new_survivor : SurvivorData)
@warning_ignore("unused_signal")
signal in_game_survivor_queuefree

func _ready() -> void:
	unknown_survivors.append(BORIS)
	unknown_survivors.append(LEO)
	unknown_survivors.append(VIKTOR)
	#unknown_survivors.append(JAVIER)
	
	##-----------TEST-----------
	known_survivors.append(JAVIER)
	#known_survivors.append(VIKTOR)
	#known_survivors.append(BORIS)
	#known_survivors.append(LEO)
	
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
