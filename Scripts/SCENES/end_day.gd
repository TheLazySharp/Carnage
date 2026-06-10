extends Control

@onready var garage: Button = $VBoxContainer/Garage

@onready var next_day: Button = $VBoxContainer/NextDay
@onready var menu: Button = $VBoxContainer/Menu

@onready var car_icon: TextureRect = $CarIcon
@onready var fortune_quantity: Label = $Fortune/FortuneQuantity


func _ready() -> void:
	garage.grab_focus()
	car_icon.texture = CarManager.selected_car.car_sprite
	fortune_quantity.text = str(InventoryManager.fortune)

func _on_upgrades_pressed() -> void:
	SceneManager.load_level(SceneManager.SCENES.GARAGE)

func _on_next_day_pressed() -> void:
	SceneManager.load_level(SceneManager.SCENES.ROADMAP)

func _on_menu_pressed() -> void:
	SceneManager.unload_game()
	SceneManager.load_level(SceneManager.SCENES.MAIN_MENU)
