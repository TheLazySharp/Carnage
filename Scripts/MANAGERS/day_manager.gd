extends Node

@onready var gm_scene: Node = $"/root/World/game_manager"
@onready var time_label: Label = $TimeUI/Time
@onready var day_label: Label = $TimeUI/Day
@onready var horde: Label = $"../CanvasLayer/Texts/Horde"
@onready var horde_animation: AnimationPlayer = $"../CanvasLayer/Texts/Horde/HordeAnimation"

@onready var barb_wire_collision: CollisionShape2D = $"../BarbWire/BarbWireCollision"


@onready var world_environment: WorldEnvironment = $"../WorldEnvironment"
@onready var directional_light_2d: DirectionalLight2D = $"../DirectionalLight2D"

@onready var day_night_cycle: CanvasModulate = $"/root/World/DayAndNightCycle"
@export var gradient_light: GradientTexture1D
@onready var time_animation_player: AnimationPlayer = $TimeUI/Time/TimeAnimationPlayer

var game_paused: bool = false
var timer_stopped :bool = false
var time_remaining: float
var critical_time: float = 0.1
var end_day_scene: String = "uid://dkpvtoel7hhai"

@onready var player: CharacterBody2D = $"../Car"
var game_start: bool = false
@onready var enemies_spawner_timer: Timer = $"../Spawners/ennemy_spawner/Timer"

var enemies_spawner_base_rate: float

signal day_ended(timer_stopped: bool)

func _ready() -> void:
	player.start_time.connect(_on_game_start)
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
	
	elif game_start: 
		time_remaining -=delta
		time_label.text = mmss_timer(time_remaining)
		var value : float = time_remaining / TimeManager.day_lenght + 0.3 #to improve
		directional_light_2d.color = gradient_light.gradient.sample(value)


	
	if time_remaining <= TimeManager.day_lenght * critical_time and !game_paused:
		time_animation_player.play("time_warning")
		

func mmss_timer(total_seconds: float) -> String:
	var seconds: float = fmod(total_seconds,60)
	var minutes: int = int(total_seconds / 60) % 60
	var mmss_string: String = "%02d:%02d" % [minutes,seconds]
	return mmss_string 


func _on_game_paused(game_on_pause : bool ) -> void:
	game_paused = game_on_pause
	
func on_day_end() -> void:
	timer_stopped = true
	emit_signal("day_ended", timer_stopped)
	horde.show()
	horde_animation.play("blinking")
	barb_wire_collision.set_deferred("disabled", true)

func _on_game_start(game_has_started : bool) -> void:
	game_start = game_has_started
