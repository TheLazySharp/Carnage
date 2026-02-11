extends Control

@onready var start: Button = $VBoxContainer/Start
@onready var quit: Button = $VBoxContainer/Quit
@onready var skip_tuto: CheckButton = $VBoxContainer/SkipTuto


var car_selection : String = "uid://b0ibe3gvcqm4q"
var tuto_scene : String = "uid://ci6t4884t7q6r"
@onready var training: Button = $VBoxContainer/Training


func _ready() -> void:
	start.grab_focus()
	if !SceneManager.tuto_completed:
		training.hide()
		skip_tuto.show()
	else: 
		training.show()
		skip_tuto.hide()
		
	

func _on_start_pressed() -> void:
	if !SceneManager.tuto_completed:
		CarManager.selected_car = CarManager.cars[0]
		StatsManager.update_car_stats(CarManager.selected_car)
		#if WeaponsManager.weapons.is_empty():
			#WeaponsManager.load_weapons()
		SceneManager.load_level(tuto_scene)
	else:
		SceneManager.unload_game()
		SceneManager.load_level(car_selection)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_training_pressed() -> void:
	CarManager.selected_car = CarManager.cars[0]
	SceneManager.load_level(tuto_scene)


func _on_skip_tuto_pressed() -> void:
	if !SceneManager.tuto_completed :
		SceneManager.tuto_completed = true

	else : SceneManager.tuto_completed = false
	
