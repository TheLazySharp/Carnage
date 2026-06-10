extends Node2D

@export var coloss_scene : PackedScene
@onready var distant_foot_steps: AudioStreamPlayer = $DistantFootSteps
@onready var explosion: AudioStreamPlayer = $Explosion
@onready var camera_2d: Camera2D = $"/root/World/Car/Camera2D"
@onready var steps_tmer: Timer = $StepsTmer

var distant : bool = false
var shake_intensity : int = 5

func _ready() -> void:
	SignalManager.day_time_end.connect(_on_day_timer_end)
	SignalManager.coloss_incoming.connect(_on_coloss_arrival)


func _on_day_timer_end(timer_stop : bool) -> void : 
	if timer_stop:
		distant = false
		explosion.play()
		camera_2d.screen_shake(30,3)
		distant_foot_steps.stop()
		for i in get_children().size():
			var coloss_auto := coloss_scene.instantiate()
			get_children()[i].add_child(coloss_auto)

func _on_coloss_arrival() -> void : 
	distant = true
	distant_foot_steps.play()
	steps_tmer.start()
	
	distant_foot_steps.volume_db = 15

func _on_steps_tmer_timeout() -> void:
	if distant:
		shake_intensity +=1
		camera_2d.screen_shake(shake_intensity,0.4)
	else :
		camera_2d.screen_shake(shake_intensity,0.4)
