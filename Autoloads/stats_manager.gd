extends Node


# ---- RAID SCORE (reset at each raid start) ----

const SCORE_SETTINGS_UID : String = "uid://dsnfw873homux"
var score_settings : ScoreSettings
var raid_kills : Dictionary[EnemyManager.Enemy_Types, int] = {}
var raid_start_distance : float = 0.0
var raid_hordes_destroyed : int = 0
var raid_maneuvers : int = 0
var raid_amplified_maneuvers : int = 0
var raid_max_combo : float = 1.0
var raid_perfect_hits : int = 0
var raid_damage_taken : int = 0
var score_extra_multiplier : float = 1.0  # free slot for a future multiplier (roadmap step, difficulty...)

var frags: int
var current_life : int
var total_drift : int
var total_car_dmg : int
var total_distance : int
@warning_ignore("unused_signal")
signal stats_updated

#MAX CAR STATS
var max_life : int = 700
var max_fuel : int = 200
var max_speed : int = 800
var display_max_speed : int = 350
var max_torque : int = 350
var max_drift : int = 4
var max_damages : int = 50
var max_dash_duration : float = 2.0 #secondes
var max_dash_damages : int = 5
var max_nitro_up : int = 20
var max_nitro_tank : int = 200

#MAX DRIFT STATS average of these stats
var max_drift_charge_speed : float = 2.0
var max_combo_step : float = 0.5
var max_drift_hit_power : float = 2.5
##  average fill of the drift stats, in percent
var max_drift_score : float = 100.0

func _ready() -> void:
	frags = 0
	total_drift = 0
	total_car_dmg = 0
	total_distance = 0
	SignalManager.distance_traveled.connect(_on_distance_traveled)

	score_settings = load(SCORE_SETTINGS_UID) as ScoreSettings
	SignalManager.start_timer.connect(reset_raid_score)
	SignalManager.enemy_is_dead.connect(_on_score_enemy_dead)
	SignalManager.horde_destroyed.connect(_on_score_horde_destroyed)
	SignalManager.maneuver_performed.connect(_on_score_maneuver)
	SignalManager.combo_changed.connect(_on_score_combo_changed)
	SignalManager.perfect_drift_hit.connect(_on_score_perfect_hit)
	SignalManager.car_blood_loss.connect(_on_score_damage_taken)

func unload() -> void:
	frags = 0
	current_life = 0
	total_drift = 0
	total_car_dmg = 0
	total_distance = 0


func _on_distance_traveled(distance_meters: int) -> void:
	total_distance += distance_meters



func get_drift_score(car : CarData, preview_part : BoostData = null, preview_level : int = -1) -> float:
	var total : float = 0.0
	total += _get_preview_value(car, car.drift_turn_bonus, preview_part, preview_level) / max_drift
	total += _get_preview_value(car, car.drift_charge_speed, preview_part, preview_level) / max_drift_charge_speed
	total += _get_preview_value(car, car.combo_step, preview_part, preview_level) / max_combo_step
	total += _get_preview_value(car, car.drift_hit_power, preview_part, preview_level) / max_drift_hit_power
	return max_drift_score * total / 4.0


## Value of a car stat, with the part raised to preview_level if that part targets it
func _get_preview_value(car : CarData, stat : Statistic, preview_part : BoostData, preview_level : int) -> float:
	if preview_part == null or !preview_part.is_car_part():
		return stat.get_value()
	var current_level : int = car.get_part_level(preview_part.car_part)
	var target_level : int = current_level + 1 if preview_level < 0 else preview_level
	if target_level <= current_level:
		return stat.get_value()
	for target_stat : BoostData.Target_Stats in preview_part.target_stats:
		if preview_part.get_car_stat(target_stat, car) == stat:
			return stat.preview_value(preview_part.make_part_preview_modifier(current_level, target_level))
	return stat.get_value()


# ---------------- RAID SCORE ----------------

func reset_raid_score() -> void:
	raid_kills.clear()
	raid_start_distance = total_distance
	raid_hordes_destroyed = 0
	raid_maneuvers = 0
	raid_amplified_maneuvers = 0
	raid_max_combo = 1.0
	raid_perfect_hits = 0
	raid_damage_taken = 0


func _on_score_enemy_dead(dead_enemy : Enemy, _horde : Array) -> void:
	raid_kills[dead_enemy.type] = raid_kills.get(dead_enemy.type, 0) + 1


func _on_score_horde_destroyed() -> void:
	raid_hordes_destroyed += 1


func _on_score_maneuver(maneuver_type : ManeuverManager.Type, _intensity : float, _drift_level : int, is_amplified : bool, _attack_angle : float) -> void:
	if maneuver_type == ManeuverManager.Type.LOOP:
		return
	raid_maneuvers += 1
	if is_amplified:
		raid_amplified_maneuvers += 1


func _on_score_combo_changed(multiplier : float, _combo_count : int) -> void:
	raid_max_combo = maxf(raid_max_combo, multiplier)


func _on_score_perfect_hit(_hit_position : Vector2) -> void:
	raid_perfect_hits += 1


func _on_score_damage_taken(damages : int) -> void:
	raid_damage_taken += damages


## { "lines": [{ "key", "count", "points", "subtotal" }], "subtotal", "combo_multiplier", "extra_multiplier", "total" }.
## Lines with a count of 0 are left out. The damage line comes last, with negative points and subtotal
func get_raid_score() -> Dictionary:
	var lines : Array[Dictionary] = []
	# Kills in the enemy type order, whatever the kill order
	for enemy_type : int in EnemyManager.Enemy_Types.values():
		if raid_kills.has(enemy_type):
			_add_score_line(lines, "SCORE_KILLS_" + EnemyManager.Enemy_Types.keys()[enemy_type], raid_kills[enemy_type], score_settings.kill_points.get(enemy_type, 0))
	var distance_steps : int = floori((total_distance - raid_start_distance) / maxf(score_settings.distance_unit, 1.0))
	_add_score_line(lines, "SCORE_DISTANCE", distance_steps, score_settings.distance_points)
	_add_score_line(lines, "SCORE_HORDES", raid_hordes_destroyed, score_settings.horde_points)
	_add_score_line(lines, "SCORE_MANEUVERS", raid_maneuvers, score_settings.maneuver_points)
	_add_score_line(lines, "SCORE_AMPLIFIED", raid_amplified_maneuvers, score_settings.amplified_maneuver_points)
	_add_score_line(lines, "SCORE_PERFECT_HITS", raid_perfect_hits, score_settings.perfect_hit_points)
	var subtotal : int = 0
	for line : Dictionary in lines:
		subtotal += line["subtotal"]
	# Damages taken: a negative line
	var penalty : int = roundi(raid_damage_taken * score_settings.damage_taken_points)
	if penalty > 0:
		lines.append({"key": "SCORE_DAMAGE_TAKEN", "count": raid_damage_taken, "points": -score_settings.damage_taken_points, "subtotal": -penalty})
		subtotal -= penalty
	subtotal = maxi(subtotal, 0)
	var combo_multiplier : float = 1.0 + (raid_max_combo - 1.0) * score_settings.combo_total_share
	return {
		"lines": lines,
		"subtotal": subtotal,
		"combo_multiplier": combo_multiplier,
		"extra_multiplier": score_extra_multiplier,
		"total": roundi(subtotal * combo_multiplier * score_extra_multiplier),
	}


func _add_score_line(lines : Array[Dictionary], key : String, count : int, points : int) -> void:
	if count <= 0:
		return
	lines.append({"key": key, "count": count, "points": points, "subtotal": count * points})
