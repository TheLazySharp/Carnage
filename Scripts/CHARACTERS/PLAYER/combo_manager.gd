extends Node
class_name ComboManager
## Combo multiplier. Its window, step, decay and max are car statistics (CarData),
## so level-ups and charms can modify them
@onready var car: CharacterBody2D = $".."

@export var streak_acceleration: float = 0.5        # each chained maneuver raises the next gain by this share
@export var amplified_gain_multiplier: float = 2.0  # gain multiplier for a maneuver completed while dashing
@export var break_on_wall_hit: bool = true          # a wall hit ends the window (the chain is lost)
@export_range(0.0, 0.5) var window_shrink_per_streak: float = 0.1  # each chained maneuver shortens the next window by this share
@export var min_window: float = 2.0                                # the window never gets shorter than this (seconds)
@export var decay_height_scaling: float = 0.0                      # 0 = constant decay; 0.5 = decays 3x faster at x5 than at x1
const JUICE = preload("uid://dbohpdgym7v6q")
var last_drift_hit_time: float = -1000.0  # real time of the last perfect drift hit not used yet

var combo_multiplier: float = 1.0
var streak: int = 0                              # distinct maneuvers chained in the current window
var last_maneuver: int = -1                      # -1 = no chain running
var window_left: float = 0.0
var window_duration: float = 1.0                 # window length at its last refresh (gauge ratio)
var game_paused: bool = false

# HUD (absent in map test scenes)
var multiplier_label: Label = null
var count_label: Label = null
var combo_gauge: ProgressBar = null


func _ready() -> void:
	multiplier_label = get_node_or_null("../../CanvasLayer/HUD/Combos/ComboMulti") as Label
	count_label = get_node_or_null("../../CanvasLayer/HUD/Combos/CountCombo") as Label
	combo_gauge = get_node_or_null("../../CanvasLayer/HUD/Combos/ComboGauge") as ProgressBar
	if combo_gauge != null:
		# Smooth 0..1 gauge: remaining share of the combo window
		combo_gauge.min_value = 0.0
		combo_gauge.value = 0.0
		combo_gauge.max_value = 1.0
		combo_gauge.step = 0.0
		combo_gauge.show_percentage = false
	SignalManager.maneuver_performed.connect(_on_maneuver_performed)
	SignalManager.perfect_drift_hit.connect(_on_perfect_drift_hit)
	SignalManager.wall_collision.connect(_on_wall_collision)
	SignalManager.game_paused.connect(_on_game_paused)
	# Only runs while the window is open or the multiplier is decaying
	set_physics_process(false)
	_update_hud()


func _physics_process(delta: float) -> void:
	if game_paused:
		return
	if window_left > 0.0:
		window_left -= delta
		if window_left <= 0.0:
			_break_chain()
		elif combo_gauge != null:
			combo_gauge.value = window_left / window_duration
		return
	# Window over: the multiplier slowly decays back to x1
	var car_data: CarData = car.player
	# Higher combos fall faster when decay_height_scaling > 0
	var decay_rate: float = car_data.combo_decay.get_value() * (1.0 + (combo_multiplier - 1.0) * decay_height_scaling)
	combo_multiplier = maxf(combo_multiplier - decay_rate * delta, 1.0)
	SignalManager.combo_changed.emit(combo_multiplier, streak)
	if combo_multiplier <= 1.0:
		set_physics_process(false)
	_update_hud()


func _on_maneuver_performed(maneuver_type: ManeuverManager.Type, _intensity: float, drift_level: int, is_amplified: bool, _attack_angle: float) -> void:
	# The loop (car ultimate) benefits from the combo but does not feed it
	if maneuver_type == ManeuverManager.Type.LOOP:
		SignalManager.maneuver_rated.emit(maneuver_type, drift_level, is_amplified, false)
		return
	var car_data: CarData = car.player
	# Dash or perfect drift hit during the maneuver: amplified for the combo
	var drift_hit_used: bool = _consume_drift_hit()
	var boosted: bool = is_amplified or drift_hit_used
	SignalManager.maneuver_rated.emit(maneuver_type, drift_level, is_amplified, drift_hit_used)
	if maneuver_type != last_maneuver or boosted:
		streak += 1
		var gain: float = car_data.combo_step.get_value() * (1.0 + (streak - 1) * streak_acceleration)
		if boosted:
			gain *= amplified_gain_multiplier
		combo_multiplier = minf(combo_multiplier + gain, car_data.combo_max.get_value())
		last_maneuver = maneuver_type
	# The longer the chain, the shorter the window: the top of the combo is hard to hold
	window_duration = maxf(car_data.combo_window.get_value() * pow(1.0 - window_shrink_per_streak, maxi(streak - 1, 0)), min_window)
	window_left = window_duration
	set_physics_process(true)
	_update_hud()
	SignalManager.combo_changed.emit(combo_multiplier, streak)


func _on_wall_collision() -> void:
	if break_on_wall_hit and window_left > 0.0:
		_break_chain()


func _on_game_paused(game_on_pause: bool) -> void:
	game_paused = game_on_pause


func _break_chain() -> void:
	# The chain is lost but the multiplier stays: it decays in _physics_process
	streak = 0
	last_maneuver = -1
	window_left = 0.0
	if combo_multiplier <= 1.0:
		set_physics_process(false)
	_update_hud()
	SignalManager.combo_changed.emit(combo_multiplier, streak)


func _update_hud() -> void:
	if multiplier_label != null:
		multiplier_label.visible = combo_multiplier > 1.0
		multiplier_label.text = "x%.1f" % combo_multiplier
	if count_label != null:
		count_label.visible = streak > 0
		count_label.text = "%d COMBO" % streak
	if combo_gauge != null:
		var window_open: bool = window_left > 0.0
		combo_gauge.visible = window_open
		combo_gauge.value = window_left / window_duration if window_open else 0.0

func _on_perfect_drift_hit(_hit_position: Vector2) -> void:
	last_drift_hit_time = Time.get_ticks_msec() / 1000.0


## True when a perfect drift hit landed during the maneuver that just ended. Used once
func _consume_drift_hit() -> bool:
	if !JUICE.drift_hit_counts_for_combo:
		return false
	if Time.get_ticks_msec() / 1000.0 - last_drift_hit_time > JUICE.drift_hit_combo_window:
		return false
	last_drift_hit_time = -1000.0
	return true
