extends Node2D

var current_item : ItemData
@onready var icon: TextureRect = $Icon

@onready var player: CharacterBody2D = $"/root/World/Car"

var velocity: Vector2
var target_pos: Vector2
var speed : = 500

#---- JUICE
const SPAWN_SPEED_MIN : float = 200.0
const SPAWN_PEED_MAX : float = 400.0
const SPAWN_GRAVITY : float = 400.0
const SPAWN_DURATION : float = 0.6

var spawn_velocity : Vector2 = Vector2.ZERO
var is_building_spawn_phase : bool = false
var is_attracted : bool = false
var can_be_collected : bool = true
var game_paused : bool = false

var spawn_origin : Vector2
var landing_pos : Vector2
var spawn_elapsed : float = 0.0


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player") and can_be_collected:
		var item : ItemData = current_item
		var effect : ItemEffect = item.effect_script.new()
		effect.activate()
		ItemManager.register(item, effect)
		queue_free()


func building_launch_spawn(origin : Vector2, landing : Vector2, spawn_item_res : ItemData) -> void:
	can_be_collected = false
	current_item = spawn_item_res
	icon.texture = current_item.icon
	spawn_origin = origin
	landing_pos = landing
	global_position = origin
	is_building_spawn_phase = true
	spawn_elapsed = 0.0


func _on_spawn_ended() -> void : 
	is_building_spawn_phase = false
	can_be_collected = true

func _physics_process(delta: float) -> void:
	if game_paused :
		return
	
	if is_building_spawn_phase:
		spawn_elapsed += delta
		var t : float = clampf(spawn_elapsed / SPAWN_DURATION, 0.0, 1.0)
		var ease_t : float = 1.0 - pow(1.0 - t, 3.0)
		global_position = spawn_origin.lerp(landing_pos, ease_t)
		# arc optionnel : global_position.y -= sin(t * PI) * 24.0
		if t >= 1.0:
			_on_spawn_ended()
		return


func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
