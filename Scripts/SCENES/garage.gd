extends Control

@onready var craft: Button = $VBoxContainer/Craft
@onready var manage: Button = $VBoxContainer/Manage
@onready var next_day: Button = $VBoxContainer/NextDay


var next_scene = "uid://c6msxridefxxd"
var menu_scene = "uid://gmjjc1vmgcds"


func _ready() -> void:
	craft.grab_focus()


func _on_craft_pressed() -> void:
	pass # Replace with function body.


func _on_manage_pressed() -> void:
	pass # Replace with function body.


func _on_next_day_pressed() -> void:
	SceneManager.load_level(next_scene)
