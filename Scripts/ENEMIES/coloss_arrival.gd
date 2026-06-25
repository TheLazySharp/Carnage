extends Node2D

@export var coloss_scene : PackedScene
@onready var distant_foot_steps: AudioStreamPlayer = $DistantFootSteps
@onready var explosion: AudioStreamPlayer = $Explosion
@onready var camera_2d: Camera2D = $"/root/World/Car/Camera2D"
@onready var steps_timer: Timer = $StepsTmer

@export var is_active : bool = false
var distant : bool = false
var shake_intensity : int = 5

func _ready() -> void:
	SignalManager.day_time_end.connect(_on_day_timer_end)
	SignalManager.coloss_incoming.connect(_on_coloss_arrival)
	SignalManager.game_paused.connect(_on_game_paused)


func _on_day_timer_end(timer_stop : bool) -> void : 
	if !is_active:
		return
	if timer_stop:
		distant = false
		explosion.play()
		camera_2d.screen_shake(30,3)
		distant_foot_steps.stop()
		for i in get_children().size():
			var coloss_auto := coloss_scene.instantiate()
			get_children()[i].add_child(coloss_auto)

func _on_coloss_arrival() -> void : 
	if !is_active:
		return
	distant = true
	distant_foot_steps.play()
	steps_timer.start()
	
	distant_foot_steps.volume_db = 15

func _on_steps_tmer_timeout() -> void:
	if distant:
		shake_intensity +=1
		camera_2d.screen_shake(clamp(shake_intensity,10,20),0.4)
	else :
		camera_2d.screen_shake(clamp(shake_intensity,10,20),0.4)


func _on_game_paused(game_is_paused : bool) -> void : 
	steps_timer.paused = game_is_paused
	
