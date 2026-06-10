extends Node2D

@onready var loop_test: PathFollow2D = $Path2D/LoopTest
@onready var camera_2d: Camera2D = $"/root/World/Car/Camera2D"
@onready var foot_steps_expl: AudioStreamPlayer = $FootStepsExpl
@onready var close_foot_steps: AudioStreamPlayer = $CloseFootSteps

var auto_progress : float = 1.5

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)

func _process(_delta: float) -> void:
	loop_test.progress += auto_progress

func _on_game_paused(game_paused : bool) -> void :
	if game_paused : 
		auto_progress = 0
		close_foot_steps.stream_paused = true
	else : 
		auto_progress += 1.5
		close_foot_steps.stream_paused = false
