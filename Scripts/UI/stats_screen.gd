extends Control

var player = CarManager.selected_car
@onready var max_health: Label = $VBoxContainer/MaxHealth
@onready var speed: Label = $VBoxContainer/Speed
@onready var healing_pow: Label = $VBoxContainer/HealingPow

@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:=false

func _ready() -> void: 
	gm_scene.game_paused.connect(_on_game_paused)

	max_health.text = "Max Life : " + str(player.max_life)
	speed.text = "Speed : " + str(player.max_speed)

func _process(_delta: float) -> void:
	max_health.text = "Max Life : " + str(player.max_life)
	speed.text = "Speed : " + str(player.max_speed)
	
	if game_paused and Input.is_action_pressed("show_stats"):
		show()
	if game_paused and Input.is_action_just_released("show_stats"):
		hide()

func _on_game_paused(game_on_pause) -> void:
	game_paused = game_on_pause
