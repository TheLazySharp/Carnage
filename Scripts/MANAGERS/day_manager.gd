extends Node


@onready var time_label: Label = $"../CanvasLayer/HUD/TimeUI/Time"
#@onready var day_label: Label = $TimeUI/Day

#@onready var barriere: Node2D = $"../Land_layers/Barriere"

@onready var world_environment: WorldEnvironment = $"../WorldEnvironment"
@onready var directional_light_2d: DirectionalLight2D = $"../DirectionalLight2D"

#@onready var day_night_cycle: CanvasModulate = $"/root/World/DayAndNightCycle"
#@export var gradient_light: GradientTexture1D
@onready var time_animation_player: AnimationPlayer = $"../CanvasLayer/HUD/TimeUI/Time/TimeAnimationPlayer"

var game_paused : bool = false
var timer_stopped : bool = false
var danger_incoming : bool = false
var half_time : bool = false
var danger_threshold : float = 10
var time_remaining : float
var critical_time : float = 0.1
var end_day_scene : String = "uid://dkpvtoel7hhai"

var player: CharacterBody2D = null
var garage_arrow: AnimatedSprite2D = null
var game_start: bool = false
var enemies_spawner_base_rate: float

## Extraction zone, published by the map generator
var extraction_position : Vector2 = Vector2.ZERO
var has_extraction : bool = false

#signal day_ended(timer_stopped: bool)

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	garage_arrow = player.get_node_or_null("TutoArrow/GarageArrow")
	player.start_time.connect(_on_game_start)
	time_remaining = TimeManager.day_lenght
	TimeManager.current_day +=1
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.map_generated.connect(_on_map_generated)
	#day_label.text = "DAY "+str(TimeManager.current_day)
	#enemies_spawner_base_rate = enemies_spawner_timer.wait_time
	
	#TEST
	#enemies_spawner_timer.wait_time = 0.3


func _process(delta: float) -> void:
	#enemies_spawner_timer.wait_time = 0.3 + enemies_spawner_base_rate * (time_remaining/TimeManager.day_lenght)
	if game_paused or timer_stopped: return
	
	if time_remaining <= 0:
		time_remaining = 0
		on_day_end()
	
	elif game_start: 
		time_remaining -=delta
		time_label.text = mmss_timer(time_remaining)
		#var value : float = time_remaining / TimeManager.day_lenght + 0.3 #to improve
		#directional_light_2d.color = gradient_light.gradient.sample(value)

	if time_remaining <= TimeManager.day_lenght * critical_time and !game_paused:
		time_animation_player.play("time_warning")

	if time_remaining < TimeManager.day_lenght * 0.5 and !half_time:
		half_time = true
		SignalManager.emit_signal("half_time")
		
	if time_remaining < danger_threshold and !danger_incoming:
		danger_incoming = true
		SignalManager.emit_signal("coloss_incoming")

func mmss_timer(total_seconds: float) -> String:
	var seconds: float = fmod(total_seconds,60)
	var minutes: int = int(total_seconds / 60) % 60
	var mmss_string: String = "%02d:%02d" % [minutes,seconds]
	return mmss_string 


func _on_game_paused(game_on_pause : bool ) -> void:
	game_paused = game_on_pause
	
func on_day_end() -> void:
	timer_stopped = true
	SignalManager.emit_signal("day_time_end", timer_stopped)
	garage_arrow.play("moving")
	garage_arrow.show()
	if has_extraction:
		SignalManager.emit_signal("tuto_arrow_dir", extraction_position)


func _on_game_start(game_has_started : bool) -> void:
	game_start = game_has_started

func _on_map_generated(data : MapData) -> void:
	if data.exit_node_idx < 0 or data.exit_node_idx >= data.nodes.size():
		return
	# nodes are stored in CELL coordinates, as floats
	extraction_position = data.nodes[data.exit_node_idx] * float(data.cell_size)
	extraction_position.x -= float(data.cell_size * 3)
	has_extraction = true
