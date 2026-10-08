extends Node2D

@export var flamer_data : WeaponData
const FLAME = preload("uid://baidslgub6j8k")

@export var auto_fire : bool = false      # legacy: permanent flames firing at enemies in range
@export var burn_duration : float = 1.5   # seconds a maneuver keeps the flames burning
@export var arc_radius : float = 30.0     # distance of the flames from the launcher
@export var ring_center_offset : Vector2 = Vector2(0.0, 20.0)  # ring center, in launcher local space (follows the car rotation)

@onready var car : CharacterBody2D = $"/root/World/Car"

var flames : Array[Area2D] = []
var combo_multiplier : float = 1.0

func _ready() -> void:
	if auto_fire:
		flamer_data.nb_projectile.stat_adjusted.connect(_on_nb_projectile_changed)
		spawn_flame(car.rotation)
		return
	# Maneuver mode: a pool of idle flames, placed and lit on each maneuver
	for i : int in flamer_data.max_projectile:
		var flame : Area2D = FLAME.instantiate()
		add_child(flame)
		flames.append(flame)
	SignalManager.maneuver_performed.connect(_on_maneuver_performed)
	SignalManager.combo_changed.connect(_on_combo_changed)


func spawn_flame(car_rotation : float, p_nb_projectile : int = int(flamer_data.nb_projectile.get_value()), origin : Vector2 = self.global_position) -> void : 
	if get_child_count(false) > 0:
		for i in get_children().size():
			get_children()[i].queue_free()
	var angle_step : float = 30
	var start_angle : float = -((p_nb_projectile - 1) * angle_step) * .5

	for i in range(p_nb_projectile):
		var angle : float = car_rotation + deg_to_rad(start_angle + i * angle_step)
		var offset : Vector2 = Vector2.RIGHT.rotated(angle) * arc_radius
		var flame : Area2D = FLAME.instantiate()
		flame.auto_fire = true
		add_child(flame)
		flame.global_position = origin + offset
		flame.global_rotation = angle


func _on_nb_projectile_changed(_final_value : float) -> void : 
	spawn_flame(car.rotation)


func _on_combo_changed(multiplier : float, _combo_count : int) -> void:
	combo_multiplier = multiplier


func _on_maneuver_performed(maneuver_type: ManeuverManager.Type, intensity: float, drift_level: int, is_amplified: bool, attack_angle: float) -> void:
	if !flamer_data.weapon_is_active or LoadoutManager.get_weapon(maneuver_type) != flamer_data:
		return
	var pattern : Vector3 = ManeuverManager.get_pattern(maneuver_type)
	if pattern.z < 0.0:
		return
	var count : int = mini(flamer_data.get_salvo_count(maneuver_type, intensity, drift_level, is_amplified, combo_multiplier), flames.size())
	var damage_multiplier : float = flamer_data.get_combo_damage_multiplier(combo_multiplier)
	var ring_center : Vector2 = to_global(ring_center_offset)
	for i : int in count:
		var angle : float = ManeuverManager.get_spread_angle(i, count, pattern.y, attack_angle)
		var flame : Area2D = flames[i]
		flame.global_rotation = angle
		flame.global_position = ring_center + Vector2.RIGHT.rotated(angle) * arc_radius
		flame.ignite(burn_duration, damage_multiplier)
