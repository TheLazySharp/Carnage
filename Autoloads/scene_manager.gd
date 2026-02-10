extends Node

var scenes: Dictionary[String,String] = {
	"MainMenu" : "uid://gmjjc1vmgcds",
	"CarSelection" : "uid://b0ibe3gvcqm4q",
	"GameOver" : "uid://c6ue1qnj30p5b",
	"EndDay" : "uid://dkpvtoel7hhai",
	"Garage" : "uid://cs311xlcqlrt0",
	"Tuto" : "uid://ci6t4884t7q6r",
	"Level01" : "uid://c6msxridefxxd"
}

#TEST = true
var tuto_completed: bool = true


var ready_go_timer: float = 2.0

func load_level(uid: String) -> void:
	get_tree().call_deferred("change_scene_to_file", uid)

func unload_game() -> void:
	XPManager.unload()
	WeaponsManager.unload()
	InventoryManager.unload()
	StatsManager.unload()
