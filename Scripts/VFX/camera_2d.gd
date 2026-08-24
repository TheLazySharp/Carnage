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


func _ready() -> void:
	zoom = Vector2(zoom_base, zoom_base)
	target_zoom = zoom_base
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

	offset = _clamped_offset(lookahead_offset) + shake_offset
	zoom_punch = lerpf(zoom_punch, 0.0, 4.0 * delta)
	zoom = zoom.lerp(Vector2.ONE * (target_zoom + zoom_punch), zoom_speed * delta)
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


func screen_shake(intensity : float, time : float) -> void:
	if !enable_shake:
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
