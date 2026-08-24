extends Node

var game_on_pause:= false
var day_is_ended:=false
var game_is_over:= false

@onready var directional_light_2d: DirectionalLight2D = $"../DirectionalLight2D"

@onready var player: CharacterBody2D = null
@onready var pause_manager: Control = $"../CanvasLayer/Pause"

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	player.game_over.connect(_update_game_over)
	pause_manager.quit_pause.connect(_update_ingame_pause)
	SignalManager.game_paused.connect(_leveling_pause)
	ShopManager.load_pools()
	ItemManager.load_pools()
	BuildingsManager.load_pools()
	TimeManager.load_time()
	
func _process(_delta: float) -> void:
	process_inputs()
	
func process_inputs()-> void:
	if Input.is_action_just_released("pause"):
		#if prelevelling.visible:
			#return
		pause_status()

func pause_status()-> void:
	if !game_on_pause:
		game_on_pause = true
		#print("game paused by player")
		SignalManager.emit_signal("game_paused", game_on_pause)
		pause_manager.show()
		pause_manager.get_focus()
	else:
		game_on_pause = false
		SignalManager.emit_signal("game_paused", game_on_pause)
		#print("game unpaused by player")
		pause_manager.hide()


func _update_game_over(game_over : bool) -> void:
	game_is_over = game_over
	if game_is_over:
		SceneManager.load_level(SceneManager.SCENES.GAME_OVER)

func _update_ingame_pause(ingame_pause : bool) -> void:
	game_on_pause = ingame_pause
	pause_status()

func _leveling_pause(leveling_pause : bool) -> void:
	game_on_pause = leveling_pause
	#SignalManager.emit_signal("game_paused", game_on_pause)
