extends Control

@onready var restart: Button = $VBoxContainer/Restart
@onready var menu: Button = $VBoxContainer/Menu
@onready var quit: Button = $VBoxContainer/Quit


var first_scene = "uid://c6msxridefxxd"
var menu_scene = "uid://gmjjc1vmgcds"


func _ready() -> void:
	restart.grab_focus()

func _on_restart_pressed() -> void:
	SceneManager.load_level(first_scene)
	SceneManager.unload_game()
	WeaponsManager.load_weapons()


func _on_menu_pressed() -> void:
	SceneManager.load_level(menu_scene)
	SceneManager.unload_game()

func _on_quit_pressed() -> void:
	get_tree().quit()
