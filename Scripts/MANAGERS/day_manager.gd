extends Node

@onready var gm_scene: Node = $"/root/World/game_manager"
@onready var time_label: Label = $TimeUI/Time
@onready var day_label: Label = $TimeUI/Day

@onready var day_night_cycle: CanvasModulate = $"/root/World/DayAndNightCycle"
@export var gradient_light: GradientTexture1D
@onready var time_animation_player: AnimationPlayer = $TimeUI/Time/TimeAnimationPlayer

var game_paused:=false
var timer_stopped :=false
var time_remaining: float
var critical_time: float = 0.1
var hut_scene:= "uid://cs311xlcqlrt0"

@onready var enemies_spawner_timer: Timer = $"../Car/Camera2D/ennemy_spawner/Timer"
var enemies_spawner_base_rate: float

signal day_ended(timer_stopped: bool)

func _ready() -> void:
	time_remaining = TimeManager.day_lenght
	TimeManager.current_day +=1
	gm_scene.game_paused.connect(_on_game_paused)
	day_label.text = "DAY "+str(TimeManager.current_day)
	enemies_spawner_base_rate = enemies_spawner_timer.wait_time


func _process(delta: float) -> void:
	
	enemies_spawner_timer.wait_time = 0.3 + enemies_spawner_base_rate * (time_remaining/TimeManager.day_lenght)
	if game_paused or timer_stopped: return
	
	if time_remaining <= 0:
		time_remaining = 0
		on_day_end()
	
	else: 
		time_remaining -=delta
		time_label.text = mmss_timer(time_remaining)
		var value = time_remaining / TimeManager.day_lenght + 0.4 #to improve
		day_night_cycle.color = gradient_light.gradient.sample(value)
	
	if time_remaining <= TimeManager.day_lenght * critical_time and !game_paused:
		time_animation_player.play("time_warning")
		

func mmss_timer(total_seconds: float) -> String:
	var seconds: float = fmod(total_seconds,60)
	var minutes: int = int(total_seconds / 60) % 60
	var mmss_string: String = "%02d:%02d" % [minutes,seconds]
	return mmss_string 


func _on_game_paused(game_on_pause) -> void:
	game_paused = game_on_pause
	
func on_day_end():
	timer_stopped = true
	emit_signal("day_ended", timer_stopped)
	SceneManager.load_level(hut_scene)
