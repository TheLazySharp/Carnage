extends Node2D

const LANDMINE = preload("uid://b6sojfyjbslm1")

@export var launcher_data : WeaponData


var game_paused:=false
@onready var cool_down: Timer = $CoolDown
var cool_down_upgrade : float
@onready var car : CharacterBody2D = $"/root/World/Car"
@onready var mine_marker: Marker2D = $"/root/World/Car/MineMarker"
@onready var drop_mine_sfx: AudioStreamPlayer2D = $DropMineSfx
@onready var flow_field : FlowFieldManager = get_node_or_null("/root/World/FlowFieldManager") as FlowFieldManager
@onready var maneuver_manager : ManeuverManager = $"/root/World/Car/ManeuverManager"


# ---- MANEUVER-DRIVEN FIRE -----
@export var auto_fire : bool = false      # legacy cooldown drops
@export var mine_spacing : float = 18.0        # spacing of the fallback line behind the car (no drift path)
@export var mine_trail_length : float = 250.0  # length of the recent drift path the mines are spread along

var combo_multiplier : float = 1.0

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.maneuver_performed.connect(_on_maneuver_performed)
	SignalManager.combo_changed.connect(_on_combo_changed)

	cool_down.wait_time = launcher_data.base_cool_down
	#max_lvl = launcher_data.max_level
	drop_mine_sfx.stream = launcher_data.weapon_sfx

	cool_down.wait_time = launcher_data.cool_down.get_value()
	launcher_data.cool_down.stat_adjusted.connect(_on_cool_down_modified)

func _process(_delta: float) -> void:
	if game_paused and !cool_down.paused:
		cool_down.paused = true
	
	if !game_paused and cool_down.paused:
		cool_down.paused = false 
	
	if !launcher_data.weapon_is_active:
		desactivate()

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause


func _on_cool_down_timeout() -> void:
	if !auto_fire or !launcher_data.weapon_is_active: return
	drop_mine()

func drop_mine()-> void:
	for i in range(1,launcher_data.nb_projectile.get_value() + 1):
		var landmine : Node2D = LANDMINE.instantiate()
		get_node("/root/World/Explosives").add_child(landmine)
		landmine.global_position = mine_marker.global_position
		drop_mine_sfx.play()
		await get_tree().create_timer(0.2).timeout
	
func desactivate() -> void:
	cool_down.stop()

func _on_cool_down_modified(new_value : float) -> void : 
	cool_down.wait_time = new_value

func _on_combo_changed(multiplier : float, _combo_count : int) -> void:
	combo_multiplier = multiplier


func _on_maneuver_performed(maneuver_type: ManeuverManager.Type, intensity: float, drift_level: int, is_amplified: bool, _attack_angle: float) -> void:
	if !launcher_data.weapon_is_active or game_paused or LoadoutManager.get_weapon(maneuver_type) != launcher_data:
		return
	if ManeuverManager.get_pattern(maneuver_type).z < 0.0:
		return
	drop_mines_on_trail(launcher_data.get_salvo_count(maneuver_type, intensity, drift_level, is_amplified, combo_multiplier))


func drop_mines_on_trail(count : int) -> void:
	# Recent part of the drift path recorded by the ManeuverManager (rear axle, points ~evenly spaced)
	var trail : PackedVector2Array = maneuver_manager.trail_points
	var trail_points_kept : int = ceili(mine_trail_length / maneuver_manager.loop_sample_distance)
	var first : int = maxi(maneuver_manager.trail_start, trail.size() - trail_points_kept)
	var available : int = trail.size() - first
	# At most one mine per trail point: the extra mines go on a tight line behind the car
	var on_trail : int = mini(count, available) if available >= 2 else 0

	var explosives : Node = get_node("/root/World/Explosives")
	for i : int in count:
		var mine_position : Vector2
		if i < on_trail:
			# Evenly spread along the path: the points are evenly spaced, so by index is by length
			var index : int = first + roundi(float(i) * (available - 1) / maxf(on_trail - 1, 1.0))
			mine_position = trail[index]
		else:
			mine_position = get_fallback_position(i - on_trail)
		var landmine : Node2D = LANDMINE.instantiate()
		landmine.damage_multiplier = launcher_data.get_combo_damage_multiplier(combo_multiplier)
		explosives.add_child(landmine)
		landmine.global_position = mine_position
	drop_mine_sfx.play()


func get_fallback_position(index : int) -> Vector2:
	# No drift path (stationary burnout, horn...): tight line behind the car, for chain explosions
	var backward : Vector2 = Vector2.LEFT.rotated(car.global_rotation)
	var candidate : Vector2 = mine_marker.global_position + backward * mine_spacing * index
	if flow_field != null and flow_field.field_ready and flow_field.is_blocked_world(candidate):
		return car.global_position
	return candidate
