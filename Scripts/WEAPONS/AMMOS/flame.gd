extends Area2D

@export var flame_data : WeaponData
var damages : int
var damages_upgrade : int

var current_lvl : int
var max_lvl : int
var enemies_can_burn: bool = false
var is_firing: bool = false
var burning: bool = true
var targets: Array[Node2D]
var auto_fire: bool = false          # set by the launcher: legacy fire-on-contact mode
var damage_multiplier: float = 1.0   # set on ignite (combo)
var fire_time_left: float = 0.0      # maneuver mode: remaining burn time

@onready var player: Sprite2D =  $"/root/World/Car/CarSprite"
@onready var flame_sfx: AudioStreamPlayer2D = $FlameSfx

@onready var jet: GPUParticles2D = $Flamethrower
@onready var collision_pol: CollisionPolygon2D = $CollisionPolygon2D

@onready var burn_rate: Timer = $BurnRate

var game_paused: bool =false


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)

	max_lvl = flame_data.max_level
	flame_sfx.stream = flame_data.weapon_sfx
	damages = int(flame_data.dmg.get_value())
	# GPUParticles2D emits by default: pooled flames must stay off until ignited
	jet.emitting = false

func _process(delta: float) -> void:

	if !flame_data.weapon_is_active:
		desactivate()

	# Maneuver mode: burns for a set time, whatever is in the area
	if fire_time_left > 0.0 and !game_paused:
		fire_time_left -= delta
		if fire_time_left <= 0.0:
			extinguish()

	if is_firing:
		burn_enemies()
	
func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
	jet.speed_scale = 0.0 if game_paused else 1.0

func throw_fire() -> void:
	if !flame_data.weapon_is_active:
		return
	is_firing = true
	jet.emitting = true
	flame_sfx.play()
	await get_tree().create_timer(0.5).timeout
	if !jet.emitting:
		return
	enemies_can_burn = true

## Maneuver mode: burn for `duration` seconds
func ignite(duration: float, p_damage_multiplier: float) -> void:
	if !flame_data.weapon_is_active:
		return
	damage_multiplier = p_damage_multiplier
	fire_time_left = maxf(fire_time_left, duration)
	if !is_firing or !jet.emitting:
		throw_fire()


func extinguish() -> void:
	enemies_can_burn = false
	jet.emitting = false
	await get_tree().create_timer(0.5).timeout
	if fire_time_left > 0.0:
		return
	flame_sfx.stop()
	is_firing = false

func burn_enemies() -> void:
	if !targets.is_empty() and burning:
		burning = false
		burn_rate.start()
		if !enemies_can_burn:
			return
		var dealt: int = roundi(flame_data.dmg.get_value() * damage_multiplier)
		for target: Node2D in targets:
			if is_instance_valid(target):
				target.get_damages(dealt, Vector2.ZERO, 0.0, flame_data.death_type)
				flame_data.total_damages_dealt += dealt

func _on_area_entered(area: Area2D) -> void:
		if area.is_in_group("ennemies") and "get_damages" in area.get_parent():
			targets.append(area.get_parent())
			# Legacy auto mode: fire when the first enemy comes in
			if auto_fire and targets.size() <= 1:
				throw_fire()
		else : return


func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group("ennemies") and "get_damages" in area.get_parent():
		targets.erase(area.get_parent())
		# Legacy auto mode: stop when the area is empty
		if auto_fire and targets.is_empty():
			enemies_can_burn = false
			await get_tree().create_timer(0.5).timeout
			jet.emitting = false
			await get_tree().create_timer(0.5).timeout
			flame_sfx.stop()
			is_firing = false
			targets.clear()
	else : return

func _on_burn_rate_timeout() -> void:
	burning = true

func desactivate() -> void:
	jet.emitting = false
	hide()
	is_firing = false
	burning = false
	enemies_can_burn = false
	targets.clear()
