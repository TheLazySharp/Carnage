extends Control

@onready var start: Button = $VBoxContainer/Start
@onready var quit: Button = $VBoxContainer/Quit
@onready var skip_tuto: CheckButton = $VBoxContainer/SkipTuto

var survivor_selection : String = "uid://cui5s6rmjs40o"
var tuto_scene : String = "uid://ci6t4884t7q6r"
var commands_scene : String = "uid://dayxnnf2ndx5c"
@onready var training: Button = $VBoxContainer/Commands


func _ready() -> void:
	
	#TUTO TO BE UPDATED
	SceneManager.tuto_completed = true
	
	start.grab_focus()
	if !SceneManager.tuto_completed:
		training.hide()
		skip_tuto.show()
	else: 
		training.show()
		skip_tuto.hide()


func _on_start_pressed() -> void:
	if !SceneManager.commands_displayed:
		SceneManager.load_level(SceneManager.SCENES.COMMANDS)
		return
	
	if !SceneManager.tuto_completed:
		CarManager.selected_car = CarManager.cars[0]

		#SceneManager.load_level(SceneManager.SCENES.tuto)
	else:
		#SceneManager.unload_game()
		SceneManager.load_level(SceneManager.SCENES.SURVIVORS)
		SignalManager.emit_signal("game_paused",false)

func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_skip_tuto_pressed() -> void:
	if !SceneManager.tuto_completed :
		SceneManager.tuto_completed = true

	else : SceneManager.tuto_completed = false


func _on_god_mode_pressed() -> void:
		lunch_god_mode()
		SignalManager.emit_signal("game_paused",false)


func lunch_god_mode() -> void : 
		GameMaster.game_mode = GameMaster.GAME_MODES.GOD
		TimeManager.day_lenght = 120
		SceneManager.load_level(SceneManager.SCENES.SURVIVORS)
	


func _on_commands_pressed() -> void:
	SceneManager.load_level(SceneManager.SCENES.COMMANDS)
	SceneManager.commands_from_menu = true


func _on_race_pressed() -> void:
	CarManager.selected_car = CarManager.cars[0]
	CarManager.selected_car.init_stats()

	SceneManager.load_level(SceneManager.SCENES.RACE)
