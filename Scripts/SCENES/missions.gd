extends Control

var menu_scene : String = "uid://gmjjc1vmgcds"
var car_selection : String = "uid://b0ibe3gvcqm4q"
var commands_scene : String = "uid://dayxnnf2ndx5c"
@onready var ok: Button = $VBoxContainer/Ok


func _ready() -> void:
	ok.grab_focus()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_back"):
		SceneManager.load_level(commands_scene)


func _on_back_pressed() -> void:
	if !SceneManager.commands_displayed:
		SceneManager.load_level(car_selection)
		SceneManager.commands_displayed = true
		return
	SceneManager.commands_displayed = true
	SceneManager.load_level(menu_scene)
