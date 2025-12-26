extends Node

var game_on_pause:= false
var game_is_over:= false
signal game_paused(game_on_pause: bool)

@onready var player: CharacterBody2D = $"../Car"
@onready var day_manager: Node = $"../DayManager"
@onready var pause_manager: Control = $"../CanvasLayer/Pause"
@onready var leveling: Control = $"../CanvasLayer/Leveling"

var game_over_scene:= "uid://c6ue1qnj30p5b"


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	player.game_over.connect(_update_game_over)
	day_manager.day_ended.connect(_update_pause_status)
	pause_manager.quit_pause.connect(_update_ingame_pause)
	leveling.game_paused.connect(_leveling_pause)
	
func _process(_delta: float) -> void:
	process_inputs()
	
	
func process_inputs()-> void:
	if Input.is_action_just_released("pause"):
		pause_status()

func pause_status()-> void:
	if not game_on_pause:
		game_on_pause = true
		print("game paused by player")
		emit_signal("game_paused", game_on_pause)
		pause_manager.show()
		pause_manager.get_focus()
	else:
		if !leveling.visible:
			game_on_pause = false
			emit_signal("game_paused", game_on_pause)
			print("game unpaused by player")
			pause_manager.hide()
		else: return

func _update_game_over(game_over):
	game_is_over = game_over
	if game_is_over:
		SceneManager.load_level(game_over_scene)

func _update_pause_status(day_ended):
	game_on_pause = day_ended

func _update_ingame_pause(ingame_pause):
	game_on_pause = ingame_pause
	pause_status()

func _leveling_pause(leveling_pause):
	game_on_pause = leveling_pause
	emit_signal("game_paused", game_on_pause)
	
