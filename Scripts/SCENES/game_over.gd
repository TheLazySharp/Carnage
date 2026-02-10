extends Control

@onready var restart: Button = $VBoxContainer/Restart
@onready var menu: Button = $VBoxContainer/Menu
@onready var quit: Button = $VBoxContainer/Quit


var car_selection : String = "uid://b0ibe3gvcqm4q"
var menu_scene : String= "uid://gmjjc1vmgcds"


func _ready() -> void:
	restart.grab_focus()

func _on_restart_pressed() -> void:
	SceneManager.load_level(car_selection)
	SceneManager.unload_game()


func _on_menu_pressed() -> void:
	WeaponsManager.unload()
	SceneManager.load_level(menu_scene)
	SceneManager.unload_game()

func _on_quit_pressed() -> void:
	get_tree().quit()
