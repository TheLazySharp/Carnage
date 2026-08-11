extends Camera2D


# ---- TOGGLES JUICE ----
@export var enable_shake : bool = true
@export var enable_lookahead : bool = true
@export var enable_dynamic_zoom : bool = true
@export var enable_drift_roll : bool = true

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


func _ready() -> void:
	zoom = Vector2(zoom_base, zoom_base)
	target_zoom = zoom_base
	SignalManager.screen_shake_requested.connect(screen_shake)
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.start_autopilot_transition.connect(_on_autopilot_transition_start)
	SignalManager.end_autopilot_transition.connect(_on_exit_transition)


func _physics_process(delta : float) -> void:
	# ---- SHAKE (tourne même en pause, comme avant) ----
	if active_shake_time > 0:
		shake_time += delta * shake_time_speed
		active_shake_time -= delta
		shake_offset = Vector2(
			noise.get_noise_2d(shake_time, 0) * shake_intensity,
			noise.get_noise_2d(0, shake_time) * shake_intensity)
		shake_intensity = max(shake_intensity - shake_decay * delta, 0)
	else:
		shake_offset = shake_offset.lerp(Vector2.ZERO, 10.5 * delta)

	offset = lookahead_offset + shake_offset
	zoom = zoom.lerp(Vector2.ONE * target_zoom, zoom_speed * delta)
	rotation = lerp_angle(rotation, deg_to_rad(target_roll), roll_speed * delta)

	# ---- SUIVI VOITURE (remplace les appels update_* faits par rigid_car) ----
	if !is_instance_valid(car):
		car = get_tree().get_first_node_in_group("player_car") as CharacterBody2D
		if car == null:
			return

	if tracking_enabled and !game_paused:
		if enable_lookahead:
			update_lookahead(car.velocity)
		else:
			update_lookahead(Vector2.ZERO)  # ramène l'offset à zéro en douceur
		if !zoom_locked:
			if enable_dynamic_zoom:
				update_zoom(car.velocity.length())
			else:
				target_zoom = zoom_base
		if enable_drift_roll:
			update_roll(car.get_drift_factor())
		else:
			target_roll = 0.0


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
	top_level = true  # caméra fixe
	if is_instance_valid(car):
		global_position = car.global_position


func _on_game_paused(paused : bool) -> void:
	game_paused = paused
