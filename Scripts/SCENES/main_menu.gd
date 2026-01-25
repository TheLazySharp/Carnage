extends Control

@onready var start: Button = $VBoxContainer/Start
@onready var quit: Button = $VBoxContainer/Quit


var car_selection = "uid://b0ibe3gvcqm4q"

func _ready() -> void:
	start.grab_focus()
	

func _on_start_pressed() -> void:
	SceneManager.load_level(car_selection)


func _on_quit_pressed() -> void:
	get_tree().quit()
