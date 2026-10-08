extends Node2D

const GRENADE = preload("uid://bsg62y0n5jpku")

@export var grenade_belt_data : WeaponData

var game_paused:=false
@onready var cool_down: Timer = $CoolDown
var cool_down_upgrade : float
@onready var car : CharacterBody2D = $"/root/World/Car"

@onready var grenade_launch_sfx: AudioStreamPlayer2D = $GrenadeLaunchSFX

# ---- MANEUVER-DRIVEN FIRE -----
@export var auto_fire: bool = false   # legacy cooldown throws in random directions
@export var sfx_min_interval: float = 0.12  # one launch sound at most every N seconds
@export var sfx_polyphony: int = 3          # overlapping launch sounds before the oldest is cut

var combo_multiplier: float = 1.0
var salvo: ManeuverSalvo = ManeuverSalvo.new()
var sfx_cooldown: float = 0.0

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.maneuver_performed.connect(_on_maneuver_performed)
	SignalManager.combo_changed.connect(_on_combo_changed)

	cool_down.wait_time = grenade_belt_data.base_cool_down
	grenade_launch_sfx.stream = grenade_belt_data.weapon_sfx
	# Several launch sounds can overlap instead of cutting each other
	grenade_launch_sfx.max_polyphony = sfx_polyphony

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
	if !auto_fire or !grenade_belt_data.weapon_is_active: return
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

func _physics_process(delta: float) -> void:
	if game_paused:
		return
	sfx_cooldown -= delta
	var due: int = salvo.advance(delta)
	if due == 0:
		return
	var explosives: Node = get_node("/root/World/Explosives")
	for i: int in due:
		var grenade : Node2D = GRENADE.instantiate()
		explosives.add_child(grenade)
		grenade.launch_grenade(global_position, salvo.next_angle(), salvo.damage_multiplier)
	# One sound per volley, not per grenade
	if sfx_cooldown <= 0.0:
		grenade_launch_sfx.play()
		sfx_cooldown = sfx_min_interval


func _on_combo_changed(multiplier: float, _combo_count: int) -> void:
	combo_multiplier = multiplier


func _on_maneuver_performed(maneuver_type: ManeuverManager.Type, intensity: float, drift_level: int, is_amplified: bool, attack_angle: float) -> void:
	if !grenade_belt_data.weapon_is_active or game_paused or LoadoutManager.get_weapon(maneuver_type) != grenade_belt_data:
		return
	salvo.start(grenade_belt_data, maneuver_type, intensity, drift_level, is_amplified, attack_angle, combo_multiplier)
