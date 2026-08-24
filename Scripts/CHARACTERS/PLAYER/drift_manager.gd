extends Node2D

@onready var skid_parent : Node2D = get_node("/root/World/SkidMarks")

@onready var drift_label : Label = $"../../CanvasLayer/HUD/DRIFT"
@onready var total_label : Label = $"../../CanvasLayer/HUD/TotalDrift"
@onready var drift_multi_label : Label = $"../../CanvasLayer/HUD/DriftMulti"

# ---------------- AUTO SLIDE ----------------
@export var enable_auto_slide : bool = true
@export_group("Auto slide")
@export var slide_grip : float = 0.04            # close to drift_grip (0.015), the rear really steps out
@export var slide_steer_threshold : float = 0.85 # |steer| mini to slide
@export var slide_speed_ratio : float = 0.7      # % of max speed to slide
@export var slide_grip_lerp : float = 6.0
@export var slide_turn_bonus : float = 1.5       # extra rotation while sliding, between 1.0 (none) and drift_turn_bonus (3.2): the slide takes an angle like a lighter manual drift
@export var slide_damping_mult : float = 0.5     # drift forward damping applied at half strength while sliding
@export var slide_volume_offset_db : float = -10.0
@export var slide_skid_width : float = 3.0
@export var slide_skid_alpha : float = 0.45

# ---------------- DRIFT CHARGE (Mario Kart style mini-turbo) ----------------
# Holding a drift charges tiers: rear trails change color and get thicker.
# Releasing a charged drift grants a speed boost.
@export_group("Drift charge")
@export var enable_drift_charge : bool = true
@export var charge_tier_time : float = 0.9   # seconds of drifting per tier
@export var charge_colors : Array[Color] = [
	Color(3.0, 0.1, 0.1, 0.9),   # tier 0 : red (base)
	Color(3.0, 2.2, 0.2, 0.95),  # tier 1 : gold
	Color(0.3, 1.6, 3.0, 1.0),   # tier 2 : electric blue
]
@export var enable_charge_boost : bool = true
@export var boost_per_tier : float = 70.0            # velocity kick per tier on release (currently unused)
@export var boost_max_speed_per_tier : float = 0.1   # +10% temporary max speed per tier
@export var boost_torque : float = 2.0               # temporary acceleration multiplier on release
@export var boost_duration : float = 0.6

var drift_charge : float = 0.0
var charge_tier : int = 0

var game_paused : bool = false

var car : CharacterBody2D
var player : CarData

var drifting : bool = false
var sliding : bool = false
var was_drifting : bool = false
var skidding_last_frame : bool = false
var skid_is_slide : bool = false

var current_grip : float = 0.0
var drift_grip : float = 0.0
var normal_grip : float = 0.0
var max_drift_damping : float = 0.0
var min_drift_speed : float = 0.0
var snap_grip : float = 0.0
var snap_speed : float = 0.0

# ---------------- SKID ----------------
var rear_left : Marker2D
var rear_right : Marker2D
var skid_spacing : float = 0.0
var skid_lifetime : float = 0.0
var skid_fade_speed : float = 0.0
var left_line : Line2D = null
var right_line : Line2D = null
var left_border : Line2D = null
var right_border : Line2D = null
var last_left_pos : Vector2 = Vector2.ZERO
var last_right_pos : Vector2 = Vector2.ZERO

# ---------------- REAR LIGHT TRAILS ----------------
var left_trail : Line2D = null
var right_trail : Line2D = null
var last_left_trail_pos : Vector2 = Vector2.ZERO
var last_right_trail_pos : Vector2 = Vector2.ZERO
var trail_spacing : float = 2.0
var trail_lifetime : float = 0.3

# ---------------- AUDIO ----------------
@onready var drift_sfx : AudioStreamPlayer2D = $DriftSfx
var drift_sfx_base_volume : float = 0.0

# ---------------- DRIFT BONUS -> increase car DMG ----------------
var drift_bonus : int = 0
var total_drift_points : int = 0
var drift_point_add : float = 0.0
var car_dmg_mod : Modifier

var debug_mode : bool = false

func _ready() -> void:
	if GameMaster.is_debug():
		_ready_debug()
		return
	SignalManager.wall_collision.connect(_on_wall_collision)
	SignalManager.game_paused.connect(_on_game_paused)
	drift_sfx_base_volume = drift_sfx.volume_db
	drift_bonus = 0
	total_drift_points = StatsManager.total_drift
	drift_point_add = snappedf(total_drift_points * 0.0001, 0.01)
	drift_label.text = str(get_drift_bonus_points())
	total_label.text = str(total_drift_points) + " pts"
	drift_multi_label.text = " DMG + " + str(drift_point_add)


func init_drift(car_node : CharacterBody2D, data : CarData, p_rear_left : Marker2D, p_rear_right : Marker2D) -> void:
	car = car_node
	player = data
	rear_left = p_rear_left
	rear_right = p_rear_right

	drift_grip = player.drift_grip
	normal_grip = player.normal_grip
	max_drift_damping = player.max_drift_damping
	min_drift_speed = player.min_drift_speed
	snap_grip = player.snap_grip
	snap_speed = player.snap_speed
	current_grip = normal_grip

	skid_spacing = player.skid_spacing
	skid_lifetime = player.skid_lifetime
	skid_fade_speed = player.skid_fade_speed

	player.dmg.remove_modifiers_from("drift manager bonus")
	car_dmg_mod = Modifier.new(int(drift_point_add), Modifier.Type.FLAT, "drift manager bonus")
	player.dmg.add_modifier(car_dmg_mod)


func _process(_delta : float) -> void:
	if get_drift_bonus_points() <= 0:
		drift_label.hide()
	else:
		drift_label.show()
		drift_label.text = str(get_drift_bonus_points())


func update_drift(delta : float, input_drifting : bool, p_forward_velocity : Vector2, p_lateral_velocity : Vector2, p_forward : Vector2, p_velocity : Vector2) -> Vector2:
	drifting = input_drifting

	var forward_velocity : Vector2 = p_forward_velocity
	var lateral_velocity : Vector2 = p_lateral_velocity
	var steer : float = get_steer_input()

	# ------------------- AUTO SLIDE DETECTION (with hysteresis to avoid flickering)
	if enable_auto_slide and !drifting:
		var speed_ok : bool
		var steer_ok : bool
		if sliding:
			speed_ok = p_velocity.length() >= player.unscaled_speed() * slide_speed_ratio * 0.9
			steer_ok = abs(steer) >= slide_steer_threshold - 0.15
		else:
			speed_ok = p_velocity.length() >= player.unscaled_speed() * slide_speed_ratio
			steer_ok = abs(steer) >= slide_steer_threshold
		sliding = speed_ok and steer_ok
	else:
		sliding = false

	# ------------------- SLIDE & DAMPING (drift and auto-slide, slide at reduced strength)
	if (drifting or sliding) and forward_velocity.length() > min_drift_speed:
		if p_velocity.length() > 10:
			var slip_angle : float = clamp(abs(p_velocity.angle_to(p_forward)) / (PI / 2), 0.0, 1.0)
			var damping : float
			var forward_damp : float = 1.0
			if abs(steer) > 0.05:
				damping = lerp(0.0, max_drift_damping, slip_angle)
			else:
				forward_damp = 0.99
				damping = 0.0
			if sliding:
				damping *= slide_damping_mult
			forward_velocity *= (1.0 - damping * delta) * forward_damp

	# ----------------- GRIP -----------------
	if drifting:
		current_grip = drift_grip
	elif sliding:
		current_grip = lerp(current_grip, slide_grip, slide_grip_lerp * delta)
	elif was_drifting:
		current_grip = lerp(current_grip, snap_grip, snap_speed * delta)
	else:
		current_grip = lerp(current_grip, normal_grip, 4.0 * delta)

	lateral_velocity = lateral_velocity.lerp(Vector2.ZERO, current_grip)

	# ----------------- SKIDS -----------------
	var skidding : bool = drifting or sliding

	if skidding and !skidding_last_frame:
		start_skid(sliding)
	elif skidding and skid_is_slide != sliding:
		# drift <-> slide transition: restart the skid with the right style
		end_skid()
		start_skid(sliding)
	elif skidding:
		update_skid_points()

	if !skidding and skidding_last_frame:
		end_skid()

	# ----------------- DRIFT CHARGE (mini-turbo) -----------------
	if enable_drift_charge and drifting:
		drift_charge += delta
		var tier : int = clampi(int(drift_charge / charge_tier_time), 0, charge_colors.size() - 1)
		if tier != charge_tier:
			charge_tier = tier
			apply_charge_tier()
	elif !drifting:
		drift_charge = 0.0
		charge_tier = 0

	was_drifting = drifting
	skidding_last_frame = skidding
	player.drifting = drifting

	return forward_velocity + lateral_velocity


func apply_charge_tier() -> void:
	# Whole trail switches color + gets thicker: instantly readable tier feedback
	for trail : Line2D in [left_trail, right_trail]:
		if trail != null:
			trail.default_color = charge_colors[charge_tier]
			trail.width = 2.0 + charge_tier * 1.5


func start_skid(is_slide : bool) -> void:
	skid_is_slide = is_slide
	drift_sfx.volume_db = drift_sfx_base_volume + (slide_volume_offset_db if is_slide else 0.0)
	drift_sfx.play()

	var left_pair : Array = create_skid_line(is_slide)
	var right_pair : Array = create_skid_line(is_slide)

	left_line = left_pair[0]
	left_border = left_pair[1]
	right_line = right_pair[0]
	right_border = right_pair[1]

	skid_parent.add_child(left_border)
	skid_parent.add_child(left_line)
	skid_parent.add_child(right_border)
	skid_parent.add_child(right_line)

	last_left_pos = Vector2.ZERO
	last_right_pos = Vector2.ZERO

	# Light trails: real drift only
	if !is_slide:
		left_trail = create_trail_line()
		right_trail = create_trail_line()
		skid_parent.add_child(left_trail)
		skid_parent.add_child(right_trail)
		last_left_trail_pos = Vector2.ZERO
		last_right_trail_pos = Vector2.ZERO


func create_skid_line(is_slide : bool) -> Array:
	var border : Line2D = Line2D.new()
	border.width = (slide_skid_width + 4.0) if is_slide else 10.0
	border.default_color = Color(1, 1, 1, 0.8 * (slide_skid_alpha if is_slide else 1.0))
	border.antialiased = true
	border.z_index = -10

	var line : Line2D = Line2D.new()
	line.width = slide_skid_width if is_slide else 6.0
	line.default_color = Color(0, 0, 0, slide_skid_alpha if is_slide else 1.0)
	line.antialiased = true
	line.z_index = -9
	return [line, border]


func create_trail_line() -> Line2D:
	var trail : Line2D = Line2D.new()
	trail.width = 2
	trail.default_color = charge_colors[0] if charge_colors.size() > 0 else Color(3.0, 0.1, 0.1, 0.9)
	trail.antialiased = true
	trail.z_index = 2
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	return trail


func update_skid_points() -> void:
	var left_wheel : Vector2 = rear_left.global_position
	var right_wheel : Vector2 = rear_right.global_position

	if last_left_pos == Vector2.ZERO:
		left_line.add_point(left_wheel)
		left_border.add_point(left_wheel)
		right_line.add_point(right_wheel)
		right_border.add_point(right_wheel)
		last_left_pos = left_wheel
		last_right_pos = right_wheel
	else:
		if left_wheel.distance_to(last_left_pos) > skid_spacing:
			left_line.add_point(left_wheel)
			left_border.add_point(left_wheel)
			last_left_pos = left_wheel
		if right_wheel.distance_to(last_right_pos) > skid_spacing:
			right_line.add_point(right_wheel)
			right_border.add_point(right_wheel)
			last_right_pos = right_wheel

	# LIGHT TRAILS (drift only)
	if left_trail == null:
		return

	var car_right : Vector2 = Vector2.RIGHT.rotated(car.rotation)
	var trail_offset : float = 6.0
	var left_wheel_trail : Vector2 = rear_left.global_position + car_right * trail_offset
	var right_wheel_trail : Vector2 = rear_right.global_position - car_right * trail_offset

	if last_left_trail_pos == Vector2.ZERO:
		left_trail.add_point(left_wheel_trail)
		right_trail.add_point(right_wheel_trail)
		last_left_trail_pos = left_wheel_trail
		last_right_trail_pos = right_wheel_trail
	else:
		if left_wheel_trail.distance_to(last_left_trail_pos) > trail_spacing:
			left_trail.add_point(left_wheel_trail)
			last_left_trail_pos = left_wheel_trail
		if right_wheel_trail.distance_to(last_right_trail_pos) > trail_spacing:
			right_trail.add_point(right_wheel_trail)
			last_right_trail_pos = right_wheel_trail

	var max_trail_points : int = 40
	if left_trail.get_point_count() > max_trail_points:
		left_trail.remove_point(0)
	if right_trail.get_point_count() > max_trail_points:
		right_trail.remove_point(0)


func fade_and_destroy(line : Line2D, border : Line2D) -> void:
	drift_sfx.stop()
	if line == null:
		return
	var tween : Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(line, "default_color:a", 0.0, skid_lifetime)
	tween.tween_property(border, "default_color:a", 0.0, skid_lifetime)
	tween.set_parallel(false)
	tween.tween_callback(line.queue_free)
	tween.tween_callback(border.queue_free)


func fade_trail(trail : Line2D) -> void:
	if trail == null:
		return
	var tween : Tween = create_tween()
	tween.tween_property(trail, "default_color:a", 0.0, trail_lifetime)
	tween.tween_callback(trail.queue_free)


func end_skid() -> void:
	total_drift_points += drift_bonus
	StatsManager.total_drift += drift_bonus
	animation_score_to_total()

	# Mini-turbo: releasing a charged drift grants a boost
	if enable_charge_boost and charge_tier > 0 and car != null:
		var boost_mod : Modifier = Modifier.new(1.0 + boost_max_speed_per_tier * charge_tier, Modifier.Type.PERCENT_MULT, "drift_charge_boost", boost_duration)
		var torque_mod : Modifier = Modifier.new(boost_torque, Modifier.Type.PERCENT_MULT, "drift_charge_accel_boost", boost_duration)
		player.max_speed.add_temp_modifier(boost_mod)
		player.acceleration.add_temp_modifier(torque_mod)
	drift_charge = 0.0
	charge_tier = 0

	fade_and_destroy(left_line, left_border)
	fade_and_destroy(right_line, right_border)
	fade_trail(left_trail)
	fade_trail(right_trail)

	left_line = null
	left_border = null
	right_line = null
	right_border = null
	left_trail = null
	right_trail = null


func force_stop_skid() -> void:
	if left_line != null:
		fade_and_destroy(left_line, left_border)
		left_line = null
		left_border = null
	if right_line != null:
		fade_and_destroy(right_line, right_border)
		right_line = null
		right_border = null
	if left_trail != null:
		fade_trail(left_trail)
		left_trail = null
	if right_trail != null:
		fade_trail(right_trail)
		right_trail = null

	drifting = false
	sliding = false
	skidding_last_frame = false
	was_drifting = false


func get_drift_factor() -> float:
	if car.velocity.length() < 10.0 or !(drifting or sliding):
		return 0.0
	var forward : Vector2 = Vector2.RIGHT.rotated(car.rotation)
	var angle : float = forward.angle_to(car.velocity.normalized())
	return clamp(angle / deg_to_rad(20.0), -1.0, 1.0)


func is_drifting() -> bool:
	return drifting


func is_sliding() -> bool:
	return sliding


func get_slide_turn_bonus() -> float:
	return slide_turn_bonus


func get_steer_input() -> float:
	return Input.get_action_strength("move_right") - Input.get_action_strength("move_left")


func get_drift_bonus_points() -> int:
	if drifting:
		if !game_paused:
			var forward : Vector2 = Vector2.RIGHT.rotated(car.rotation)
			var angle : float = abs(forward.angle_to(car.velocity.normalized()))
			var angle_factor : float = clamp(angle / (PI / 2), 0.0, 1.0)
			drift_bonus += int(car.velocity.length() * 0.1 * angle_factor)
	else:
		drift_bonus = 0
	return drift_bonus


func animation_score_to_total() -> void:
	if debug_mode:
		return
	if drift_bonus <= 0:
		return

	var fly_label : Label = Label.new()
	fly_label.text = str(drift_bonus)
	fly_label.add_theme_font_override("font", FontManager.FONTS[FontManager.types.UX][0])
	fly_label.add_theme_font_size_override("font_size", FontManager.FONTS[FontManager.types.UX][1])
	fly_label.add_theme_color_override("font_color", FontManager.dark_yellow)
	fly_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fly_label.add_theme_constant_override("outline_size", FontManager.UX_outline)
	drift_label.get_parent().add_child(fly_label)
	fly_label.position = Vector2(3.0, 66.0)

	var tween : Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(fly_label, "position", Vector2(500.0, 740.0), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(fly_label, "theme_override_font_sizes/font_size", 24, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(fly_label, "modulate:a", 0.0, 1.0)

	fly_label.scale = Vector2(1.8, 1.8)
	tween.tween_property(fly_label, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.set_parallel(false)
	tween.tween_callback(fly_label.queue_free)

	tween.tween_callback(func() -> void:
		drift_point_add = snappedf(total_drift_points * 0.0001, 0.01)
		total_label.text = str(total_drift_points) + " pts"
		drift_multi_label.text = "DMG + " + str(drift_point_add)

		player.dmg.remove_modifiers_from("drift manager bonus")
		car_dmg_mod = Modifier.new(int(drift_point_add), Modifier.Type.FLAT, "drift manager bonus")
		player.dmg.add_modifier(car_dmg_mod)

		var flash_tween : Tween = create_tween()
		flash_tween.tween_method(func(c : Color) -> void:
			total_label.add_theme_color_override("font_color", c),
			Color.RED, FontManager.dark_yellow, 1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	)


func _on_wall_collision() -> void:
	if drifting:
		drift_bonus = 0


func _on_game_paused(pause : bool) -> void:
	game_paused = pause


func _ready_debug() -> void:
	# Map test scene: /root/World and the HUD don't exist.
	# Local skid parent so drift physics, skid marks and charge trails work
	# unchanged; HUD labels and the score animation are disabled.
	debug_mode = true
	set_process(false)  # _process only feeds the HUD drift label
	skid_parent = Node2D.new()
	skid_parent.name = "SkidMarksDebug"
	get_tree().current_scene.add_child.call_deferred(skid_parent)
	SignalManager.wall_collision.connect(_on_wall_collision)
	SignalManager.game_paused.connect(_on_game_paused)
	drift_sfx_base_volume = drift_sfx.volume_db
	drift_bonus = 0
	total_drift_points = StatsManager.total_drift
	drift_point_add = snappedf(total_drift_points * 0.0001, 0.01)
