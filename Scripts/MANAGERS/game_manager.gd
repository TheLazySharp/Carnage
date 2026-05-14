extends Node

var game_on_pause:= false
var day_is_ended:=false
var game_is_over:= false


@onready var player: CharacterBody2D = $"../Car"
@onready var pause_manager: Control = $"../CanvasLayer/Pause"
@onready var leveling: Control = $"../CanvasLayer/Leveling"
@onready var weapons_container: MarginContainer = $"../CanvasLayer/Leveling/WeaponsContainer"
@onready var ammo_container: MarginContainer = $"../CanvasLayer/Leveling/AmmoContainer"
@onready var prelevelling: Control = $"../CanvasLayer/Prelevelling"

var game_over_scene:= "uid://c6ue1qnj30p5b"


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	player.game_over.connect(_update_game_over)
	SignalManager.day_time_end.connect(_on_day_end)
	pause_manager.quit_pause.connect(_update_ingame_pause)
	SignalManager.game_paused.connect(_leveling_pause)
	
func _process(_delta: float) -> void:
	process_inputs()
	
func process_inputs()-> void:
	if Input.is_action_just_released("pause"):
		if leveling.visible or prelevelling.visible:
			return
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
		SceneManager.load_level(game_over_scene)

func _on_day_end(day_ended : bool) -> void:
	day_is_ended = day_ended

func _update_ingame_pause(ingame_pause : bool) -> void:
	game_on_pause = ingame_pause
	pause_status()

func _leveling_pause(leveling_pause : bool) -> void:
	game_on_pause = leveling_pause
	#SignalManager.emit_signal("game_paused", game_on_pause)
