extends Panel

var displayed_car : CarData
var i : int

@onready var car_name: Label = $Name
@onready var icon: TextureRect = $Car/Icon
@onready var locked_rect: ColorRect = $Car/LockedRect
@onready var select: Button = $"../VBoxContainer/Select"
@onready var stats_panel: Panel = $StatsPanel
@export var locked_icon: Texture2D

func _ready() -> void:
	i = 0
	CarManager.selected_car = CarManager.unlocked_cars[i]
	CarManager.selected_car.init_stats()
	update_car_data()
	select.grab_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("go_next"):
		i+=1
		if i == CarManager.all_cars.size():
			i = 0
		update_car_data()

	if event.is_action_pressed("go_previous"):
		i-=1
		if i < 0 :
			i = CarManager.all_cars.size() -1
		update_car_data()

	if event.is_action_pressed("ui_back"): 
		SceneManager.load_level(SceneManager.SCENES.SURVIVORS)


func update_car_data() -> void:
	CarManager.selected_car = CarManager.all_cars[i]
	locked_rect.visible = false if CarManager.selected_car.is_unlocked else true
	icon.texture = CarManager.selected_car.car_sprite
	car_name.text = CarManager.selected_car.car_name
	CarManager.selected_car.init_stats()
	stats_panel.hide()
	stats_panel.show()
	
func _on_select_pressed() -> void:
	if !CarManager.selected_car.is_unlocked:
		return
	match GameMaster.game_mode:
		GameMaster.GAME_MODES.BUILD:
			SceneManager.load_level(SceneManager.SCENES.START_INTRO)
		GameMaster.GAME_MODES.DEV:
			if SceneManager.race_mode:
				SceneManager.load_level(SceneManager.SCENES.RACE)
			else: 
				SceneManager.load_level(SceneManager.SCENES.ROADMAP)
		#GameMaster.GAME_MODES.GOD:
			#SceneManager.load_level(SceneManager.SCENES.GOD_MOD_TRAINING)
		GameMaster.GAME_MODES.SANDBOX:
			LoadoutManager.start_run(CarManager.selected_car)
			LoadoutManager.assign_everywhere(WeaponsManager.weapons[0])
			SceneManager.load_level(SceneManager.SCENES.SANDBOX_NEW)
	CarManager.emit_signal("car_selected")


func _on_back_pressed() -> void:
	SceneManager.load_level(SceneManager.SCENES.SURVIVORS)

func _on_next_button_pressed() -> void:
	i+=1
	if i == CarManager.all_cars.size():
		i = 0
	update_car_data()
	
func _on_previous_button_pressed() -> void:
	i-=1
	if i < 0 :
		i = CarManager.all_cars.size() -1
	update_car_data()
