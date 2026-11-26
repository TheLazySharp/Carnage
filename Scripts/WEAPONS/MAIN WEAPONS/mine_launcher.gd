extends Node2D

const LANDMINE = preload("uid://b6sojfyjbslm1")

@export var launcher_data : WeaponData


var game_paused : bool = false
@onready var cool_down: Timer = $CoolDown
var cool_down_upgrade : float
@onready var car : CharacterBody2D = $"/root/World/Car"
@onready var mine_marker: Marker2D = $"/root/World/Car/MineMarker"
@onready var drop_mine_sfx: AudioStreamPlayer2D = $DropMineSfx
@onready var flow_field : FlowFieldManager = get_node_or_null("/root/World/FlowFieldManager") as FlowFieldManager


# ---- MANEUVER-DRIVEN FIRE -----
@export var auto_fire : bool = false      # legacy cooldown drops

@export_group("Throw")
@export var drop_interval : float = 0.25       # max seconds between two mines
@export var max_salvo_duration : float = 1.5   # the queued mines are all thrown within this time (shorter interval when many)
@export var throw_distance : float = 40.0      # how far behind the car a mine lands
@export var throw_spread : float = 18.0        # random lengthwise / sideways offset: mines never stack
@export var throw_duration : float = 0.25      # flight time
@export var throw_scale_peak : float = 0.4     # fake flight: +40 % size at the top of the arc

var combo_multiplier : float = 1.0
var pending_multipliers : PackedFloat32Array = PackedFloat32Array()  # one entry per mine still to throw: its damage multiplier
var drop_timer : float = 0.0
@onready var explosives : Node = $"/root/World/Explosives"

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.maneuver_performed.connect(_on_maneuver_performed)
	SignalManager.combo_changed.connect(_on_combo_changed)
	SignalManager.maneuver_salvo_repeated.connect(_on_maneuver_performed)

	cool_down.wait_time = launcher_data.base_cool_down
	#max_lvl = launcher_data.max_level
	drop_mine_sfx.stream = launcher_data.weapon_sfx

	cool_down.wait_time = launcher_data.cool_down.get_value()
	launcher_data.cool_down.stat_adjusted.connect(_on_cool_down_modified)

func _process(delta: float) -> void:
	if game_paused and !cool_down.paused:
		cool_down.paused = true

	if !game_paused and cool_down.paused:
		cool_down.paused = false

	if !launcher_data.weapon_is_active:
		desactivate()

	# Queued mines: thrown one by one behind the car
	if pending_multipliers.is_empty() or game_paused:
		return
	drop_timer -= delta
	if drop_timer > 0.0:
		return
	_throw_next_mine()
	drop_timer = minf(drop_interval, max_salvo_duration / maxf(float(pending_multipliers.size()), 1.0))

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
	var count : int = launcher_data.get_salvo_count(maneuver_type, intensity, drift_level, is_amplified, combo_multiplier)
	# Same for every mine of this salvo (the maneuver level raises the combo share)
	var damage_multiplier : float = launcher_data.get_combo_damage_multiplier(combo_multiplier, maneuver_type)
	_queue_mines(count, damage_multiplier)


## The salvo joins the queue: an empty queue throws its first mine right away
func _queue_mines(count : int, damage_multiplier : float) -> void:
	if pending_multipliers.is_empty():
		drop_timer = 0.0
	for i : int in count:
		pending_multipliers.append(damage_multiplier)


func _throw_next_mine() -> void:
	var damage_multiplier : float = pending_multipliers[0]
	pending_multipliers.remove_at(0)
	var start : Vector2 = mine_marker.global_position
	var backward : Vector2 = Vector2.LEFT.rotated(car.global_rotation)
	var target : Vector2 = start \
			+ backward * (throw_distance + randf_range(-throw_spread, throw_spread)) \
			+ backward.orthogonal() * randf_range(-throw_spread, throw_spread)
	# A wall behind the car: the mine drops on the marker instead
	if flow_field != null and flow_field.field_ready and flow_field.is_blocked_world(target):
		target = start
	var landmine : Node2D = LANDMINE.instantiate()
	landmine.damage_multiplier = damage_multiplier
	explosives.add_child(landmine)
	landmine.global_position = start
	landmine.throw_to(target, throw_duration, throw_scale_peak)
	drop_mine_sfx.play()
