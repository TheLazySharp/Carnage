extends Node2D

@export var heal_data : WeaponData
var healing_power
var is_active:= true
var auto_heal_rythme
var current_lvl
var max_lvl


@onready var healing_timer: Timer = $HealingTimer

@onready var beaver_sr: CharacterBody2D = $"/root/World/BeaverSr"

@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:=false

func _ready() -> void:
	gm_scene.game_paused.connect(_on_game_paused)
	healing_timer.wait_time = heal_data.fire_rate
	max_lvl = heal_data.max_level
	healing_power = heal_data.healing_power
	auto_heal(healing_power)
		

func _process(_delta: float) -> void:
	current_lvl = clampi(heal_data.current_level,0,max_lvl)
	healing_power = heal_data.healing_power + (current_lvl) #améliorer la formule d'augmentation des soins
	if is_active and !game_paused:
		auto_heal(healing_power)


func _on_healing_timer_timeout() -> void:
	if "auto_heal" in beaver_sr:
		is_active = true
		auto_heal(healing_power)
	
func auto_heal(life_up):
	if "auto_heal" in beaver_sr and !game_paused:
		healing_timer.start()
		beaver_sr.auto_heal(life_up)
		is_active = false

func _on_game_paused(game_on_pause) -> void:
	game_paused = game_on_pause
