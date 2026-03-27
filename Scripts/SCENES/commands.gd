extends Control

var menu_scene : String = "uid://gmjjc1vmgcds"
var car_selection : String = "uid://b0ibe3gvcqm4q"
var missions_scene : String = "uid://dc6hb14w0yref"

@onready var ok: Button = $VBoxContainer/Ok


func _ready() -> void:
	ok.grab_focus() 


func _process(_delta: float) -> void:
	pass


func _on_back_pressed() -> void:
	SceneManager.load_level(missions_scene)
