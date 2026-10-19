extends Node

var game_paused : bool = false
var day_is_ended : bool = false
var game_is_over : bool = false

@onready var directional_light_2d: DirectionalLight2D = $"../DirectionalLight2D"

@onready var player: CharacterBody2D = null
#@onready var pause_manager: Control = $"../CanvasLayer/Pause"

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	#pause_manager.quit_pause.connect(_update_ingame_pause)
	#SignalManager.game_paused.connect(_on_game_paused)
	#BuildingsManager.load_pools()
	if !GameMaster.tutorial_active:
		player.game_over.connect(_update_game_over)
		TimeManager.load_time()
		ItemManager.load_pools()
		ShopManager.load_pools()
	
#func _process(_delta: float) -> void:
	#process_inputs()
	
#func process_inputs()-> void:
	#if Input.is_action_just_released("pause"):
		#pause_status()
#
#func pause_status()-> void:
	#if !game_paused:
		#game_paused = true
		#SignalManager.emit_signal("game_paused", game_paused)
		##pause_manager.show()
		##pause_manager.get_focus()
	#else:
		#game_paused = false
		#SignalManager.emit_signal("game_paused", game_paused)
		##pause_manager.hide()


func _update_game_over(game_over : bool) -> void:
	game_is_over = game_over
	if game_is_over:
		SceneManager.load_level(SceneManager.SCENES.GAME_OVER)

#func _update_ingame_pause(ingame_pause : bool) -> void:
	#game_paused = ingame_pause
	#pause_status()

#func _on_game_paused(paused : bool) -> void:
	#game_paused = paused

#func _leveling_pause(leveling_pause : bool) -> void:
	#game_paused = leveling_pause
	#SignalManager.emit_signal("game_paused", game_paused)
