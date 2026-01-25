extends Panel

var displayed_car : CarData
var i : int

@onready var car_name: Label = $Name
@onready var icon: TextureRect = $Icon

@onready var fuel: Label = $Stats/Fuel
@onready var speed: Label = $Stats/Speed
@onready var torque: Label = $Stats/Torque
@onready var dmg: Label = $Stats/Dmg
@onready var drift: Label = $Stats/Drift


var first_scene = "uid://c6msxridefxxd"
var menu_scene = "uid://gmjjc1vmgcds"

@onready var next: Button = $RightArrow/Next



func _ready() -> void:
	i = 0
	displayed_car = CarManager.cars[i]
	StatsManager.update_car_stats(displayed_car)
	next.grab_focus()
	update_car_data()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("go_next"):
		i+=1
		if i == CarManager.cars.size():
			i = 0
		update_car_data()
		
	if Input.is_action_just_pressed("go_previous"):
		i-=1
		if i < 0 :
			i = CarManager.cars.size() -1
		update_car_data()
	

func update_car_data():
	displayed_car = CarManager.cars[i]
	StatsManager.update_car_stats(displayed_car)
	car_name.text = displayed_car.car_name
	icon.texture = displayed_car.car_sprite
	fuel.text = "Fuel : " + str(displayed_car.max_life)
	speed.text = "Max Speed : " + str(displayed_car.display_max_speed)
	torque.text = "Torque : " + str(displayed_car.acceleration)
	dmg.text = "Dmg : " + str(displayed_car.dmg)
	drift.text = "Drift : " + str(displayed_car.drift_turn_bonus + displayed_car.turn_speed)


func _on_select_pressed() -> void:
	CarManager.selected_car = displayed_car
	StatsManager.update_car_stats(CarManager.selected_car)
	if WeaponsManager.weapons.is_empty():
		WeaponsManager.load_weapons()
	SceneManager.load_level(first_scene)


func _on_back_pressed() -> void:
	SceneManager.load_level(menu_scene)


func _on_next_button_pressed() -> void:
	i+=1
	if i == CarManager.cars.size():
		i = 0
	update_car_data()


func _on_previous_button_pressed() -> void:
	i-=1
	if i < 0 :
		i = CarManager.cars.size() -1
	update_car_data()
