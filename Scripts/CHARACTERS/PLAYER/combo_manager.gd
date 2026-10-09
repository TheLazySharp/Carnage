extends Node
class_name ComboManager

@export var combo_window: float = 4.0            # seconds to chain the next maneuver
@export var combo_step: float = 0.25             # base multiplier gain per new different maneuver
@export var streak_acceleration: float = 0.5     # each chained maneuver raises the next gain by this share
@export var decay_per_second: float = 0.25       # multiplier lost per second once the window is over
@export var combo_max_multiplier: float = 7.0
@export var break_on_wall_hit: bool = true       # a wall hit ends the window (the chain is lost)
@export var amplified_gain_multiplier: float = 2.0  # gain multiplier for a maneuver completed while dashing

var combo_multiplier: float = 1.0
var streak: int = 0                              # distinct maneuvers chained in the current window
var last_maneuver: int = -1                      # -1 = no chain running
var window_left: float = 0.0
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
			combo_gauge.value = window_left / combo_window
		return
	# Window over: the multiplier slowly decays back to x1
	combo_multiplier = maxf(combo_multiplier - decay_per_second * delta, 1.0)
	SignalManager.combo_changed.emit(combo_multiplier, streak)
	if combo_multiplier <= 1.0:
		set_physics_process(false)
	_update_hud()


func _on_maneuver_performed(maneuver_type: ManeuverManager.Type, _intensity: float, _drift_level: int, is_amplified: bool, _attack_angle: float) -> void:
	# The loop (car ultimate) benefits from the combo but does not feed it
	if maneuver_type == ManeuverManager.Type.LOOP:
		return
	# A different maneuver raises the multiplier (faster as the chain grows).
	# An amplified (dashed) maneuver always counts as new, even when repeated, and multiplies the gain.
	# A plain repeat only refreshes the window
	if maneuver_type != last_maneuver or is_amplified:
		streak += 1
		var gain: float = combo_step * (1.0 + (streak - 1) * streak_acceleration)
		if is_amplified:
			gain *= amplified_gain_multiplier
		combo_multiplier = minf(combo_multiplier + gain, combo_max_multiplier)
		last_maneuver = maneuver_type
	window_left = combo_window
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
		combo_gauge.value = window_left / combo_window if window_open else 0.0
