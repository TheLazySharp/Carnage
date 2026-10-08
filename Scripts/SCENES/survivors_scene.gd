extends Control

var survivor: SurvivorData
@onready var survivor_0: Button = $MarginContainer/BoxContainer/PNJ0
var survivor_index : int = 0



func _ready() -> void:
	survivor_0.grab_focus()
	SurvivorsManager.portrait_hovered.connect(_on_portrait_hovered)

	WeaponsManager.unload()
	jobs_manager.unload()
	SurvivorsManager.unload()
	WeaponsManager.load_weapons()

func _on_portrait_hovered(new_index : int) -> void : 
	survivor_index = new_index

func _on_select_pressed() -> void:
	if !SurvivorsManager.on_board_survivors.is_empty():
		return
	var starting_survivor : SurvivorData = SurvivorsManager.known_survivors[survivor_index]
	WeaponsManager.init_weapon(starting_survivor.weapon) #init before being instantiated when car is instantiated
	SurvivorsManager.select_survivor(starting_survivor)
	
	var job : JobData = starting_survivor.job_ressource
	var effect : JobEffect = job.effect_script.new()
	effect.activate()
	jobs_manager.register(job, effect)

	SceneManager.load_level(SceneManager.SCENES.CAR_SELECTION)
	
	if GameMaster.game_mode == GameMaster.GAME_MODES.GOD:
		WeaponsManager.init_god_mod()


func _on_back_pressed() -> void:
	SceneManager.load_level(SceneManager.SCENES.MAIN_MENU)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_back") :
		SceneManager.load_level(SceneManager.SCENES.MAIN_MENU)
		
