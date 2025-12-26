extends Node

var scenes: Dictionary[String,String] = {
	"MainMenu" : "uid://gmjjc1vmgcds",
	"GameOver" : "uid://c6ue1qnj30p5b",
	"TheHut" : "uid://cs311xlcqlrt0",
	"Level00" : "uid://dp8fuljm28ogu",
	"Level01" : "uid://c6msxridefxxd"
}



func load_level(uid: String) -> void:
	get_tree().call_deferred("change_scene_to_file", uid)

func unload_game() -> void:
	XPManager.unload()
	WeaponsManager.unload()
