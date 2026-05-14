extends Node

var scenes: Dictionary[String,String] = {
	"MainMenu" : "uid://gmjjc1vmgcds",
	"CarSelection" : "uid://b0ibe3gvcqm4q",
	"GameOver" : "uid://c6ue1qnj30p5b",
	"Start_intro" : "uid://dqfr2nck8fjao",
	"EndDay" : "uid://dkpvtoel7hhai",
	"Garage" : "uid://cs311xlcqlrt0",
	"Tuto" : "uid://ci6t4884t7q6r",
	"Level01" : "uid://c6msxridefxxd",
	"LuckyCharms" : "uid://ch2rp03kbdyg7",
	"Commands" : "uid://dayxnnf2ndx5c",
	"Missions" : "uid://dc6hb14w0yref",
	"Survivors" : "uid://cui5s6rmjs40o",
	"RoadMap" : "uid://dsn18jy5k2in8"
}

var districts_scenes : Dictionary[DistrictsData.types,String] = {
	DistrictsData.types.GARAGE :"uid://cs311xlcqlrt0",
	DistrictsData.types.MISSION :"uid://c6msxridefxxd",
	DistrictsData.types.PARKING :"uid://df565yrwfqn1v",
}

#TEST = true
var tuto_completed: bool = false
var commands_displayed : bool = false

var ready_go_timer: float = 2.0

func load_level(uid: String) -> void:
	get_tree().call_deferred("change_scene_to_file", uid)

func load_district(loading_district : DistrictsData) -> void : 
	get_tree().call_deferred("change_scene_to_file", districts_scenes[loading_district.type])
	

func unload_game() -> void:
	XPManager.unload()
	WeaponsManager.unload()
	InventoryManager.unload()
	StatsManager.unload()
	LuckyCharmsManager.unload()
	TimeManager.unload()
	RoadMapManager.unload()
	SurvivorsManager.unload()
