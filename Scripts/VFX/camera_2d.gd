extends Camera2D

# ---- TOGGLES JUICE ----
@export var enable_shake : bool = true
@export var enable_lookahead : bool = true
@export var enable_dynamic_zoom : bool = true
@export var enable_drift_roll : bool = true
@export var enable_drift_punch : bool = true
@export var drift_punch_zoom : float = 0.15

# ---- SHAKE ----
var shake_intensity : float = 0.0
var active_shake_time : float = 0.0
var shake_decay : float = 5.0
var shake_time : float = 0.0
var shake_time_speed : float = 20.0
var noise : FastNoiseLite = FastNoiseLite.new()
var shake_offset : Vector2 = Vector2.ZERO

# ---- LOOKAHEAD ----
@export var lookahead_strength : float = 80.0
@export var lookahead_speed : float = 4.0
var lookahead_offset : Vector2 = Vector2.ZERO

# ---- ZOOM IN % SPEED ----
@export var zoom_base : float = 2.0
@export var zoom_max_out : float = 1.0
@export var zoom_speed : float = 3.0
@export var speed_max : float = 600.0
var target_zoom : float = 1.0

# ---- ROLL WHEN DRIFT ----
@export var roll_max_deg : float = 10.0
@export var roll_speed : float = 20.0
var target_roll : float = 0.0

# ---- SUIVI DE LA VOITURE ----
@export var autopilot_target_zoom : float = 1.5
var car : CharacterBody2D = null
var tracking_enabled : bool = true
var zoom_locked : bool = false
var game_paused : bool = false
var zoom_tween : Tween = null
var zoom_punch : float = 0.0
var was_skidding : bool = false


# ---- PERFECT DRIFT HIT ZOOM (tuned in JuiceSettings) ----
const JUICE = preload("uid://dbohpdgym7v6q")
var smooth_zoom : float = 1.0
var hit_zoom_start : float = -1000.0    # real time of the last perfect drift hit
var hit_focus_point : Vector2 = Vector2.ZERO

# Settings of the running hit zoom (perfect drift hit or maneuver)
var hit_zoom_amount : float = 0.0
var hit_zoom_focus : float = 0.0
var hit_zoom_in : float = 0.05
var hit_zoom_hold : float = 0.0
var hit_zoom_out : float = 0.3

func _ready() -> void:
	zoom = Vector2(zoom_base, zoom_base)
	target_zoom = zoom_base
	smooth_zoom = zoom_base
	SignalManager.perfect_drift_hit.connect(_on_perfect_drift_hit)
	SignalManager.maneuver_performed.connect(_on_maneuver_performed)
	SignalManager.screen_shake_requested.connect(screen_shake)
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.start_autopilot_transition.connect(_on_autopilot_transition_start)
	SignalManager.end_autopilot_transition.connect(_on_exit_transition)
	SignalManager.map_generated.connect(_on_map_generated)


func _physics_process(delta : float) -> void:
	# ---- SHAKE ----
	if active_shake_time > 0:
		shake_time += delta * shake_time_speed
		active_shake_time -= delta
		shake_offset = Vector2(
			noise.get_noise_2d(shake_time, 0) * shake_intensity,
			noise.get_noise_2d(0, shake_time) * shake_intensity)
		shake_intensity = max(shake_intensity - shake_decay * delta, 0)
	else:
		shake_offset = shake_offset.lerp(Vector2.ZERO, 10.5 * delta)

	# Final zoom and offset are applied in _process (the hit zoom runs in real time)
	zoom_punch = lerpf(zoom_punch, 0.0, 4.0 * delta)
	smooth_zoom = lerpf(smooth_zoom, target_zoom + zoom_punch, zoom_speed * delta)
	rotation = lerp_angle(rotation, deg_to_rad(target_roll), roll_speed * delta)

	# ---- SUIVI VOITURE  ----
	if !is_instance_valid(car):
		car = get_tree().get_first_node_in_group("player") as CharacterBody2D
		if car == null:
			return

	if tracking_enabled and !game_paused:
		if enable_lookahead:
			update_lookahead(car.velocity)
		else:
			update_lookahead(Vector2.ZERO)
		if !zoom_locked:
			if enable_dynamic_zoom:
				update_zoom(car.velocity.length())
			else:
				target_zoom = zoom_base
		if enable_drift_roll:
			update_roll(car.get_drift_factor())
		else:
			target_roll = 0.0

		var skidding : bool = car.get_drift_factor() != 0.0
		if enable_drift_punch and skidding != was_skidding:
			zoom_punch = drift_punch_zoom
		was_skidding = skidding

## Final zoom and offset, every rendered frame: the hit zoom keeps moving during the hit stop,
## when the physics barely ticks
func _process(_delta : float) -> void:
	var hit_amount : float = _get_hit_zoom_amount()
	var focus_offset : Vector2 = Vector2.ZERO
	if hit_amount > 0.0:
		focus_offset = (hit_focus_point - global_position) * hit_zoom_focus * hit_amount
	zoom = Vector2.ONE * smooth_zoom * (1.0 + hit_zoom_amount * hit_amount)
	offset = _clamped_offset(lookahead_offset + focus_offset) + shake_offset


## 0 -> 1 (zoom in) -> hold during the freeze -> 0 (zoom out), in real seconds
func _get_hit_zoom_amount() -> float:
	var elapsed : float = Time.get_ticks_msec() / 1000.0 - hit_zoom_start
	var zoom_in : float = maxf(hit_zoom_in, 0.001)
	var zoom_out : float = maxf(hit_zoom_out, 0.001)
	if elapsed < 0.0 or elapsed >= zoom_in + hit_zoom_hold + zoom_out:
		return 0.0
	if elapsed < zoom_in:
		var t_in : float = elapsed / zoom_in
		return 1.0 - (1.0 - t_in) * (1.0 - t_in)  # ease out: snaps in
	if elapsed < zoom_in + hit_zoom_hold:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (elapsed - zoom_in - hit_zoom_hold) / zoom_out)


func _on_perfect_drift_hit(hit_position : Vector2) -> void:
	start_hit_zoom(hit_position, JUICE.drift_hit_zoom, JUICE.drift_hit_focus,
			JUICE.drift_hit_zoom_in_time, JUICE.drift_hit_stop_duration, JUICE.drift_hit_zoom_out_time)


func _on_maneuver_performed(maneuver_type : ManeuverManager.Type, _intensity : float, _drift_level : int, _is_amplified : bool, _attack_angle : float) -> void:
	if !JUICE.maneuver_juice_enabled or JUICE.maneuver_juice_excluded.has(maneuver_type):
		return
	# Centred on the car: no focus offset
	start_hit_zoom(global_position, JUICE.maneuver_zoom, 0.0,
			JUICE.maneuver_zoom_in_time, JUICE.maneuver_stop_duration, JUICE.maneuver_zoom_out_time)


## Punch zoom in real time. While a zoom is still coming in or holding, a weaker or equal one is ignored
## (several enemies in one swipe: a single zoom), a stronger one takes over
func start_hit_zoom(point : Vector2, amount : float, focus : float, zoom_in : float, hold : float, zoom_out : float) -> void:
	if amount <= 0.0:
		return
	var now : float = Time.get_ticks_msec() / 1000.0
	if now - hit_zoom_start < hit_zoom_in + hit_zoom_hold and amount <= hit_zoom_amount:
		return
	hit_zoom_start = now
	hit_focus_point = point
	hit_zoom_amount = amount
	hit_zoom_focus = focus
	hit_zoom_in = zoom_in
	hit_zoom_hold = hold
	hit_zoom_out = zoom_out

func screen_shake(intensity : float, time : float) -> void:
	if !enable_shake:
		return
	# A weaker shake never cuts a stronger one in progress: it only extends it
	if active_shake_time > 0.0 and intensity <= shake_intensity:
		active_shake_time = maxf(active_shake_time, time)
		return
	randomize()
	noise.seed = randi()
	noise.frequency = 2.0
	shake_intensity = intensity
	active_shake_time = time
	shake_time = 0.0


func update_lookahead(velocity : Vector2) -> void:
	if velocity.length() > 10.0:
		lookahead_offset = lookahead_offset.lerp(velocity.normalized() * lookahead_strength, lookahead_speed * get_physics_process_delta_time())
	else:
		lookahead_offset = lookahead_offset.lerp(Vector2.ZERO, lookahead_speed * get_physics_process_delta_time())


func update_zoom(speed : float) -> void:
	var t : float = clamp(speed / speed_max, 0.0, 1.0)
	target_zoom = lerp(zoom_base, zoom_max_out, t)


func update_roll(drift_factor : float) -> void:
	target_roll = drift_factor * roll_max_deg

## offset bypasses limit_*, so the lookahead must be clamped by hand — against
## the ALREADY limited view centre, not the raw global_position
func _clamped_offset(desired : Vector2) -> Vector2:
	var half_view : Vector2 = get_viewport_rect().size * 0.5 / zoom
	var min_center : Vector2 = Vector2(float(limit_left), float(limit_top)) + half_view
	var max_center : Vector2 = Vector2(float(limit_right), float(limit_bottom)) - half_view
	# Map narrower than the view: centre it, no clamping possible
	if min_center.x > max_center.x:
		min_center.x = (min_center.x + max_center.x) * 0.5
		max_center.x = min_center.x
	if min_center.y > max_center.y:
		min_center.y = (min_center.y + max_center.y) * 0.5
		max_center.y = min_center.y

	var base : Vector2 = global_position
	base.x = clampf(base.x, min_center.x, max_center.x)
	base.y = clampf(base.y, min_center.y, max_center.y)
	return Vector2(
			clampf(desired.x, min_center.x - base.x, max_center.x - base.x),
			clampf(desired.y, min_center.y - base.y, max_center.y - base.y))

# ---------------- AUTOPILOT ----------------
func _on_autopilot_transition_start() -> void:
	zoom_locked = true
	lookahead_strength = 0.0
	lookahead_offset = Vector2.ZERO

	if zoom_tween:
		zoom_tween.kill()
	zoom_tween = create_tween()
	zoom_tween.tween_property(self, "target_zoom", autopilot_target_zoom, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	zoom_tween.tween_callback(func() -> void: SignalManager.autopilot_zoom_completed.emit())


func _on_exit_transition() -> void:
	tracking_enabled = false
	zoom_locked = false
	top_level = true
	if is_instance_valid(car):
		global_position = car.global_position


func _on_game_paused(paused : bool) -> void:
	game_paused = paused

func _on_map_generated(data : MapData) -> void:
	var map_px : Vector2 = Vector2(data.map_size_cells) * float(data.cell_size)
	limit_left = 0
	limit_top = 0
	limit_right = int(map_px.x)
	limit_bottom = int(map_px.y)
	limit_smoothed = true  # no hard stop when reaching an edge
	print("[Camera] limits ", limit_left, ",", limit_top, " -> ", limit_right, ",", limit_bottom,
			" | map ", map_px, " | view ", get_viewport_rect().size / zoom)
