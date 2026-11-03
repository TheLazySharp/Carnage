extends Node2D

const SAW = preload("uid://dmpgkp1cor6kw")
@export var carrier_data : WeaponData

@export var arc_radius : float = 30.0     # distance of the saws from the launcher
@export var ring_center_offset : Vector2 = Vector2(0.0, 20.0)  # ring center, in launcher local space (follows the car rotation)
@onready var saw_launch_sfx: AudioStreamPlayer2D = $SawLaunchSFX
@onready var car : CharacterBody2D = $"/root/World/Car"
var last_sfx_time : float = -1000.0
@onready var bullets_container : Node = $"/root/World/Bullets"

@export var pool_size : int = 30  # saws created up front; more are added if a salvo needs them
var saw_pool : Array[Node2D] = []

# ---- MANEUVER-DRIVEN FIRE -----
@export var auto_fire: bool = false   # legacy auto-targeting bursts (off: fire on maneuvers only)
@export var sfx_min_interval: float = 0.08  # one shot sound at most every N seconds (no buzz)
@export var sfx_polyphony: int = 4          # overlapping shot sounds before the oldest is cut

var combo_multiplier : float = 1.0
var game_paused : bool = false

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.maneuver_performed.connect(_on_maneuver_performed)
	SignalManager.combo_changed.connect(_on_combo_changed)
	SignalManager.maneuver_salvo_repeated.connect(_on_maneuver_performed)

	saw_launch_sfx.stream = carrier_data.weapon_sfx
	# Several shot sounds can overlap instead of cutting each other
	saw_launch_sfx.max_polyphony = sfx_polyphony
	
	_create_saws(pool_size)

func _on_combo_changed(multiplier : float, _combo_count : int) -> void:
	combo_multiplier = multiplier

func _on_maneuver_performed(maneuver_type: ManeuverManager.Type, intensity: float, drift_level: int, is_amplified: bool, attack_angle: float) -> void:
	if !carrier_data.weapon_is_active or LoadoutManager.get_weapon(maneuver_type) != carrier_data:
		return
	var pattern : Vector3 = ManeuverManager.get_pattern(maneuver_type)
	if pattern.z < 0.0:
		return
	var count : int = carrier_data.get_salvo_count(maneuver_type, intensity, drift_level, is_amplified, combo_multiplier)
	if count <= 0:
		return
	var damage_multiplier : float = carrier_data.get_combo_damage_multiplier(combo_multiplier)
	var ring_center : Vector2 = to_global(ring_center_offset)
	for i : int in count:
		var angle : float = ManeuverManager.get_spread_angle(i, count, pattern.y, attack_angle)
		var direction : Vector2 = Vector2.RIGHT.rotated(angle)
		var saw : Node2D = _get_saw()
		saw.throw(ring_center + direction * arc_radius, direction, damage_multiplier)
	_play_launch_sfx()

func _create_saws(count : int) -> void:
	for i : int in count:
		var saw : Node2D = SAW.instantiate()
		saw.launcher = self
		bullets_container.add_child(saw)
		saw_pool.append(saw)

## A pooled saw, or a new one when the whole pool is in flight
func _get_saw() -> Node2D:
	if saw_pool.is_empty():
		_create_saws(1)
	return saw_pool.pop_back()

## Called by a saw when it stops (wall, off-screen)
func return_saw(saw : Node2D) -> void:
	saw_pool.append(saw)

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause

## One launch sound per salvo, at most every sfx_min_interval seconds
func _play_launch_sfx() -> void:
	var now : float = Time.get_ticks_msec() * 0.001
	if now - last_sfx_time < sfx_min_interval:
		return
	last_sfx_time = now
	saw_launch_sfx.play()
