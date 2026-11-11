extends Node2D

const BASEBALL_BAT = preload("uid://c5g74aadec237")

@export var handler_data : WeaponData
# Animation range of each maneuver (x = min, y = max, from 1 to 4). Not listed = no swing.
## Short drift / horn: (1, 2). Spin 180 / reverse spin 180: (3, 3). Spin 360 / donut / burnout: (4, 4)
@export var swing_range_by_maneuver : Dictionary[ManeuverManager.Type, Vector2i] = {}

@onready var player : CharacterBody2D = $/root/World/Car

var bat : BaseballBat
var combo_multiplier : float = 1.0
var game_paused : bool = false


func _ready() -> void:
	bat = BASEBALL_BAT.instantiate() as BaseballBat
	add_child(bat)
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.combo_changed.connect(_on_combo_changed)
	SignalManager.maneuver_performed.connect(_on_maneuver_performed)
	SignalManager.maneuver_salvo_repeated.connect(_on_maneuver_performed)


func _on_maneuver_performed(maneuver_type : ManeuverManager.Type, intensity : float, drift_level : int, is_amplified : bool, attack_angle : float) -> void:
	if !handler_data.weapon_is_active or game_paused or LoadoutManager.get_weapon(maneuver_type) != handler_data:
		return
	if !swing_range_by_maneuver.has(maneuver_type):
		return
	var swing_range : Vector2i = swing_range_by_maneuver[maneuver_type]
	var count : int = handler_data.get_salvo_count(maneuver_type, intensity, drift_level, is_amplified, combo_multiplier)
	var animation_index : int = clampi(count, swing_range.x, swing_range.y) - 1
	# Side and front / rear from the maneuver direction, in car local space (like the other weapons)
	var local_attack : Vector2 = Vector2.RIGHT.rotated(attack_angle - player.global_rotation)
	var damage : int = roundi(bat.bat_data.dmg.get_value() * handler_data.get_combo_damage_multiplier(combo_multiplier, maneuver_type))
	bat.swing(animation_index, local_attack.y > 0.0, local_attack.x < 0.0, damage)


func _on_combo_changed(multiplier : float, _combo_count : int) -> void:
	combo_multiplier = multiplier


func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
