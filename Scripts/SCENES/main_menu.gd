extends Control

@onready var start: Button = $VBoxContainer/Start
@onready var quit: Button = $VBoxContainer/Quit

@export var bow_data: WeaponData

var first_scene = "uid://c6msxridefxxd"
var level00 = ""

func _ready() -> void:
	start.grab_focus()

func _on_start_pressed() -> void:
	bow_data.bonus = false
	if WeaponsManager.weapons.is_empty():
		WeaponsManager.load_weapons()
	SceneManager.load_level(first_scene)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_test_pressed() -> void:
	bow_data.bonus = true
	if WeaponsManager.weapons.is_empty():
		WeaponsManager.load_weapons()
	SceneManager.load_level(first_scene)
