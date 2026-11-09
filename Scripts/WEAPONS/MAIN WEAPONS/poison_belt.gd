extends Node2D

const POISON_VIAL = preload("uid://dsmeqe0gu8kk6")

@export var poison_belt_data : WeaponData

var game_paused:=false
@onready var car : CharacterBody2D = $"/root/World/Car"

@onready var poison_launch_sfx: AudioStreamPlayer2D = $PoisonLaunchSFX

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
	SignalManager.maneuver_salvo_repeated.connect(_on_maneuver_performed)

	poison_launch_sfx.stream = poison_belt_data.weapon_sfx
	poison_launch_sfx.max_polyphony = sfx_polyphony


func _process(_delta: float) -> void:	
	if !poison_belt_data.weapon_is_active:
		desactivate()

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause


func _on_cool_down_timeout() -> void:
	if !auto_fire or !poison_belt_data.weapon_is_active: return
	spawn_vial(self.global_position)

func spawn_vial(from_pos : Vector2)-> void:
	for i in range(1,poison_belt_data.nb_projectile.get_value() + 1):
		var poison_vial : Node2D = POISON_VIAL.instantiate()
		get_node("/root/World/Explosives").add_child(poison_vial)
		poison_vial.launch_vial(from_pos)
	
func desactivate() -> void:
	pass

func _physics_process(delta: float) -> void:
	if game_paused:
		return
	sfx_cooldown -= delta
	var due: int = salvo.advance(delta)
	if due == 0:
		return
	var explosives: Node = get_node("/root/World/Explosives")
	for i: int in due:
		var poison_vial : Node2D = POISON_VIAL.instantiate()
		explosives.add_child(poison_vial)
		poison_vial.launch_vial(global_position, salvo.next_angle(), salvo.damage_multiplier)
	if sfx_cooldown <= 0.0:
		poison_launch_sfx.play()
		sfx_cooldown = sfx_min_interval


func _on_combo_changed(multiplier: float, _combo_count: int) -> void:
	combo_multiplier = multiplier


func _on_maneuver_performed(maneuver_type: ManeuverManager.Type, intensity: float, drift_level: int, is_amplified: bool, attack_angle: float) -> void:
	if !poison_belt_data.weapon_is_active or game_paused or LoadoutManager.get_weapon(maneuver_type) != poison_belt_data:
		return
	salvo.start(poison_belt_data, maneuver_type, intensity, drift_level, is_amplified, attack_angle, combo_multiplier)
