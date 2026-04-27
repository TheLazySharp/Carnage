extends Control

@onready var upgrades: Button = $VBoxContainer/Upgrades
@onready var next_day: Button = $VBoxContainer/NextDay
@onready var menu: Button = $VBoxContainer/Menu

@onready var car_icon: TextureRect = $CarIcon
@onready var parts_quantity: Label = $Parts/PartsQuantity


var garage_scene : String = "uid://cs311xlcqlrt0"
var next_scene : String = "uid://c6msxridefxxd"
var menu_scene : String = "uid://gmjjc1vmgcds"
var roadmap_scene : String = "uid://dsn18jy5k2in8"

func _ready() -> void:
	upgrades.grab_focus()
	car_icon.texture = CarManager.selected_car.car_sprite
	parts_quantity.text = str(InventoryManager.auto_parts)

func _on_upgrades_pressed() -> void:
	SceneManager.load_level(garage_scene)

func _on_next_day_pressed() -> void:
	SceneManager.load_level(roadmap_scene)

func _on_menu_pressed() -> void:
	SceneManager.unload_game()
	SceneManager.load_level(menu_scene)
