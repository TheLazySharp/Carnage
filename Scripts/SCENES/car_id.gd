extends Panel

var displayed_car : CarData
var i : int

@onready var car_name: Label = $Name
@onready var icon: TextureRect = $Icon

var first_scene : String = "uid://c6msxridefxxd"
var roadmap_scene : String = "uid://dsn18jy5k2in8"
var survivor_selection : String = "uid://cui5s6rmjs40o"

@onready var select: Button = $"../VBoxContainer/Select"

@onready var stats_panel: Panel = $StatsPanel


func _ready() -> void:
	i = 0
	CarManager.selected_car = CarManager.cars[i]
	CarManager.selected_car.init_stats()
	update_car_data()
	select.grab_focus()


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
	
	if Input.is_action_just_pressed("ui_back"): 
		SceneManager.load_level(survivor_selection)

func update_car_data() -> void:
	CarManager.selected_car = CarManager.cars[i]
	icon.texture = CarManager.selected_car.car_sprite
	car_name.text = CarManager.selected_car.car_name
	CarManager.selected_car.init_stats()
	stats_panel.hide()
	stats_panel.show()
	
func _on_select_pressed() -> void:
	#CarManager.selected_car = displayed_car
	SceneManager.load_level(roadmap_scene)


func _on_back_pressed() -> void:
	SceneManager.load_level(survivor_selection)


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
