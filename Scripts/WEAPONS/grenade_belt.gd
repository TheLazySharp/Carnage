extends Node2D

const GRENADE = preload("uid://bsg62y0n5jpku")


@export var grenade_belt_data : WeaponData


var game_paused:=false
@onready var cool_down: Timer = $CoolDown
var cool_down_upgrade : float
@onready var car : CharacterBody2D = $"/root/World/Car"

@onready var grenade_launch_sfx: AudioStreamPlayer2D = $GrenadeLaunchSFX


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)

	cool_down.wait_time = grenade_belt_data.base_cool_down
	grenade_launch_sfx.stream = grenade_belt_data.weapon_sfx

	cool_down.wait_time = grenade_belt_data.cool_down.get_value()
	grenade_belt_data.cool_down.stat_adjusted.connect(_on_cool_down_modified)

func _process(_delta: float) -> void:
	if game_paused and !cool_down.paused:
		cool_down.paused = true
	
	if !game_paused and cool_down.paused:
		cool_down.paused = false 
	
	if !grenade_belt_data.weapon_is_active:
		desactivate()

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause


func _on_cool_down_timeout() -> void:
	if !grenade_belt_data.weapon_is_active: return
	spawn_grenade(self.global_position)

func spawn_grenade(from_pos : Vector2)-> void:
	for i in range(1,grenade_belt_data.nb_projectile.get_value() + 1):
		var grenade : Node2D = GRENADE.instantiate()
		get_node("/root/World/Explosives").add_child(grenade)
		grenade.launch_grenade(from_pos)
	
func desactivate() -> void:
	cool_down.stop()

func _on_cool_down_modified(new_value : float) -> void : 
	cool_down.wait_time = new_value
