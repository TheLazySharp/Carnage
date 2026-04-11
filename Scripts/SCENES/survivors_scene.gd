extends Control

var survivor: SurvivorData
@onready var survivor_0: Button = $MarginContainer/BoxContainer/PNJ0
var car_selection_scene : String = "uid://b0ibe3gvcqm4q"
var menu_scene : String = "uid://gmjjc1vmgcds"
var survivor_index : int = 0

func _ready() -> void:
	survivor_0.grab_focus()
	SurvivorsManager.portrait_hovered.connect(_on_portrait_hovered)
	if WeaponsManager.weapons.is_empty():
		WeaponsManager.load_weapons()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_back"): 
		SceneManager.load_level(menu_scene)

func _on_portrait_hovered(new_index : int) -> void : 
	survivor_index = new_index


func _on_select_pressed() -> void:
	SceneManager.load_level(car_selection_scene)
	WeaponsManager.init_weapon(SurvivorsManager.known_survivors[survivor_index].weapon)
	SurvivorsManager.select_survivor(SurvivorsManager.known_survivors[survivor_index])
	print(survivor_index)


func _on_back_pressed() -> void:
	SceneManager.load_level(menu_scene)
