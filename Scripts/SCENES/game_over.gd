extends Control

@onready var restart: Button = $VBoxContainer/Restart
@onready var menu: Button = $VBoxContainer/Menu
@onready var quit: Button = $VBoxContainer/Quit


var survivor_selection : String = "uid://cui5s6rmjs40o"
var menu_scene : String= "uid://gmjjc1vmgcds"


func _ready() -> void:
	restart.grab_focus()

func _on_restart_pressed() -> void:
	SceneManager.unload_game()
	SceneManager.load_level(survivor_selection)


func _on_menu_pressed() -> void:
	SceneManager.unload_game()
	SceneManager.load_level(menu_scene)

func _on_quit_pressed() -> void:
	get_tree().quit()
