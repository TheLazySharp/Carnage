extends Node

const LEVEL_UP_ARCADE = preload("uid://btlemu36v2gmy")
const PICK_UP_XP = preload("uid://d3dy3rwu1gt4t")
const PICK_UP_GEARS = preload("uid://dw8ppl08udpfq")

var engine_db : int


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	engine_db = -11
	


func _on_game_paused(game_on_pause : bool) -> void : 
	if game_on_pause : 
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Engine"), -80)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Skids"), -80)
	else :
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Engine"), engine_db)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Skids"), engine_db)
	
