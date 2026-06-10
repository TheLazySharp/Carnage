extends Control

var car : CarData = CarManager.selected_car
	#----------TEST---------------#
#var car : CarData


@onready var entrance: Control = $Entrance
@onready var shop: Control = $Shop
@onready var stats: Control = $Stats

@onready var back: Button = $Entrance/EntranceButtons/Back
@onready var shop_button: Button = $Entrance/Buttons/Shop
@onready var stats_button: Button = $Entrance/Buttons/Stats



#-----------------ENTRANCE -------------------#
#CAR
@onready var car_name: Label = $Entrance/Repair/CarName
@onready var car_icon: TextureRect = $Entrance/Repair/CarIcon
@onready var repair_button: Button = $Entrance/RepairButton


func _ready() -> void:
	##----------TEST---------------#
	#CarManager.selected_car = CarManager.cars[0]
	#car = CarManager.selected_car
	#XPManager.current_level = 4
	#InventoryManager.auto_parts = 2000
	
	jobs_manager.emit_signal("mechanic_job")
	car_name.text = car.car_name
	car_icon.texture = car.car_sprite
	
	entrance.show()
	shop.hide()
	stats.hide()
	repair_button.grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_back"):
		#if entrance.visible and !shop.visible and !stats.visible:
			#SceneManager.load_level(roadmap_scene)
		if !entrance.visible and shop.visible or stats.visible:
			entrance.show()
			shop.hide()
			stats.hide()
			back.grab_focus()

func _on_back_pressed() -> void:
	SceneManager.load_level(SceneManager.SCENES.ROADMAP)

func _on_shop_pressed() -> void:
	entrance.hide()
	shop.show()
	stats.hide()

func _on_stats_pressed() -> void:
	entrance.hide()
	shop.hide()
	stats.show()
