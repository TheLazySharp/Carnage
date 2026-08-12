extends Node2D
class_name SpriteFXManager


@export var enable_squash_stretch : bool = true
@export var enable_lean : bool = true
@export var enable_dash_anticipation_fx : bool = true
@export var enable_chassis_inertia : bool = true

@export_group("Squash & Stretch")
@export var accel_stretch : float = 0.06        # stretch at full acceleration
@export var accel_reference : float = 400.0     # acceleration (px/s2) giving max stretch
@export var dash_stretch : float = 0.25         # stretch pulse on dash
@export var impact_squash : float = 0.18        # max squash on wall impact
@export var impact_speed_reference : float = 250.0
@export var smooth_speed : float = 8.0

@export_group("Lean")
@export var lean_max_deg : float = 4.0
@export var lean_speed : float = 6.0
@export var lean_speed_reference : float = 250.0  # speed giving max lean

@export_group("Chassis inertia (over/understeer)")
@export var inertia_gain : float = 0.45   # reaction to angular velocity changes
@export var stiffness : float = 400.0     # spring stiffness (higher = faster return)
@export var spring_damping : float = 10.0 # damping (lower = oscillates longer)
@export var max_offset_deg : float = 14.0 # max chassis travel

@export_group("Skid ghosts (arcade afterimage trail)")
@export var enable_skid_ghosts : bool = true
@export var ghost_scene : PackedScene
@export var ghost_interval : float = 0.06
@export var ghost_tint : Color = Color(1.0, 1.0, 1.0, 0.45)

var car : CharacterBody2D
var sprite : Sprite2D
var base_scale : Vector2 = Vector2.ONE
var base_rotation : float = 0.0

var game_paused : bool = false
var last_speed : float = 0.0
var stretch : float = 0.0
var lean : float = 0.0
var pulse_tween : Tween = null

# ---- CHASSIS INERTIA ----
var last_car_rotation : float = 0.0
var last_ang_vel : float = 0.0
var spring_offset : float = 0.0
var spring_vel : float = 0.0

# ---- SKID GHOSTS ----
var ghost_cooldown : float = 0.0


func init_fx(p_car : CharacterBody2D, p_sprite : Sprite2D, dash_manager : DashManager) -> void:
	car = p_car
	sprite = p_sprite
	base_scale = sprite.scale
	base_rotation = sprite.rotation
	last_car_rotation = car.rotation

	dash_manager.dash_anticipating.connect(_on_dash_anticipating)
	dash_manager.dash_started.connect(_on_dash_started)
	car.wall_impact.connect(_on_wall_impact)
	SignalManager.game_paused.connect(func(paused : bool) -> void: game_paused = paused)


func _physics_process(delta : float) -> void:
	if car == null or sprite == null or game_paused:
		return

	var speed : float = car.velocity.length()

	# ---- CONTINUOUS STRETCH (acceleration / deceleration) ----
	if enable_squash_stretch:
		var accel : float = (speed - last_speed) / maxf(delta, 0.0001)
		var target : float = clampf(accel / accel_reference, -1.0, 1.0) * accel_stretch
		stretch = lerpf(stretch, target, smooth_speed * delta)
	else:
		stretch = lerpf(stretch, 0.0, smooth_speed * delta)
	last_speed = speed

	# ---- CHASSIS INERTIA (rotational spring) ----
	var chassis : float = 0.0
	if enable_chassis_inertia:
		var ang_vel : float = wrapf(car.rotation - last_car_rotation, -PI, PI) / maxf(delta, 0.0001)
		spring_vel -= (ang_vel - last_ang_vel) * inertia_gain
		spring_vel += (-stiffness * spring_offset - spring_damping * spring_vel) * delta
		spring_offset += spring_vel * delta
		spring_offset = clampf(spring_offset, -deg_to_rad(max_offset_deg), deg_to_rad(max_offset_deg))
		last_ang_vel = ang_vel
		chassis = spring_offset
	last_car_rotation = car.rotation

	# ---- SKID GHOSTS: afterimage trail while drifting or sliding ----
	if enable_skid_ghosts and ghost_scene != null and car.get_drift_factor() != 0.0:
		ghost_cooldown -= delta
		if ghost_cooldown <= 0.0:
			ghost_cooldown = ghost_interval
			var ghost : Node2D = ghost_scene.instantiate()
			ghost.set_property(car.position, car.scale, car.rotation)
			ghost.modulate = ghost_tint
			get_tree().current_scene.add_child(ghost)

	# ---- STEERING LEAN ----
	var target_lean : float = 0.0
	if enable_lean:
		var steer : float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		var speed_factor : float = clampf(speed / lean_speed_reference, 0.0, 1.0)
		target_lean = steer * deg_to_rad(lean_max_deg) * speed_factor
	lean = lerp_angle(lean, target_lean, lean_speed * delta)

	# ---- APPLY (tween pulses take priority over scale) ----
	if pulse_tween == null or !pulse_tween.is_running():
		sprite.scale = Vector2(base_scale.x * (1.0 + stretch), base_scale.y * (1.0 - stretch * 0.5))
	sprite.rotation = base_rotation + lean + chassis


func _on_dash_anticipating() -> void:
	if !enable_dash_anticipation_fx:
		return
	# Recoil: the sprite compresses backward before the propulsion
	_pulse(Vector2(1.0 - impact_squash, 1.0 + impact_squash * 0.6), 0.09)


func _on_dash_started() -> void:
	if !enable_squash_stretch:
		return
	_pulse(Vector2(1.0 + dash_stretch, 1.0 - dash_stretch * 0.5), 0.3)


func _on_wall_impact(impact_speed : float) -> void:
	if !enable_squash_stretch:
		return
	if pulse_tween and pulse_tween.is_running():
		return  # anti-spam while scraping along a wall
	var amount : float = impact_squash * clampf(impact_speed / impact_speed_reference, 0.3, 1.0)
	_pulse(Vector2(1.0 - amount, 1.0 + amount), 0.2)


func _pulse(target_mult : Vector2, duration : float) -> void:
	if pulse_tween:
		pulse_tween.kill()
	pulse_tween = create_tween()
	pulse_tween.tween_property(sprite, "scale", base_scale * target_mult, duration * 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pulse_tween.tween_property(sprite, "scale", base_scale, duration * 0.65) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
