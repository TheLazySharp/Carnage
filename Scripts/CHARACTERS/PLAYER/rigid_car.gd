extends CharacterBody2D

var player : CarData

# ---------------- CAR DATA ----------------
var max_backward_speed : int = 0
var friction : float = 0.0
var turn_speed : float = 0.0
var velocity_floor : int = 0

@onready var car_sprite : Sprite2D = $CarSprite


# ---------------- SFX ----------------
@onready var start_engine : AudioStreamPlayer = $Audio/StartEngine
@onready var dmg_sfx : AudioStreamPlayer = $Audio/DmgSFX
@onready var dmg_sfx_2 : AudioStreamPlayer = $Audio/DmgSFX2
@onready var dmg_sfx_3 : AudioStreamPlayer = $Audio/DmgSFX3
@onready var death_sfx : AudioStreamPlayer = $Audio/DeathSfx
@onready var engine_sfx_player : Node = $Audio/Engine
var dmg_players : Array[AudioStreamPlayer] = []

# ---------------- SKID ----------------
@onready var rear_left : Marker2D = $RearLeft
@onready var rear_right : Marker2D = $RearRight
var drifting : bool = false

# ---------------- COMPONENTS ----------------
@onready var drift_manager : Node2D = $DriftManager
@onready var bloody_engine : Node2D = $BloodyEngine
@onready var burnout_manager : BurnoutManager = $BurnoutManager
@onready var dash_manager : DashManager = $DashManager
@onready var sprite_fx : SpriteFXManager = $SpriteFX
@onready var rear_left_burn_anim : AnimatedSprite2D = $RearLeft/RearLeftBurnAnim
@onready var rear_right_burn_anim : AnimatedSprite2D = $RearRight/RearRightBurnAnim

# Signals
signal burnout_ok(burnout : bool)
signal revving(revving : bool)
signal dashing
signal dash_end
signal wall_impact(impact_speed : float)

# ---------------- COLLISION / TIMERS ----------------
@onready var collision_shape : CollisionShape2D = $CollisionShape
@onready var taking_damages : Timer = $TakingDamages

# ---------------- GAME ----------------
signal game_over(game_is_over : bool)
signal start_time(game_start : bool)
signal engine_ignited
var game_is_over : bool = false
var game_paused : bool = false
var is_taking_damages : bool = false
var can_drive : bool = false
var forward_only : bool = false

# ---------------- VFX ----------------
@onready var car_explosion : AnimatedSprite2D = $VFX/CarExplosion
@onready var sparkles : CPUParticles2D = $VFX/Sparkles
@onready var drivin_smoke_r_2 : CPUParticles2D = $RearRight/DrivinSmokeR2
@onready var drivin_smoke_l_2 : CPUParticles2D = $RearLeft/DrivinSmokeL2
@onready var flash : AnimationPlayer = $CarSprite/Flash
@export var enable_skid_smoke : bool = true
var skid_smoke_active : bool = false

# ---------------- INVINCIBILITY ----------------
var invincibility_tween : Tween = null
var glow_sprite : Sprite2D = null

# ---------------- AUTOPILOT ----------------
enum AutopilotState { NONE, ZOOM, DRIVE, EXIT }
var autopilot_state : AutopilotState = AutopilotState.NONE
var autopilot_speed : float = 0.0
var autopilot_exit_accel : float = 800.0

# ---------------- CONSTANTS (former magic numbers) ----------------
const WALL_BOUNCE_DAMP : float = 0.9
const WALL_ALIGN_LERP : float = 0.3
const WALL_ROTATION_SPEED : float = 5.0
const MIN_STEER_FACTOR : float = 0.25
const WALL_IMPACT_MIN_SPEED : float = 80.0  # min frontal speed component to emit wall_impact

# ---------------- DEBUG ----------------
#@export var debug_drive_mode : bool = false  # drop the car scene in a map test scene: driving only
@export var debug_car_data : CarData = null  # CarData used when launching outside the normal game flow


func _input(event : InputEvent) -> void:
	if event.is_action_pressed("dash") and !game_paused:
		dash_manager.try_dash()

func _ready() -> void:
	add_to_group("player")  # used by the camera to find the car
	if GameMaster.is_debug():
		_ready_debug()
		return
	player = CarManager.selected_car
	if TimeManager.current_day == 1:
		player.init_stats()

	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.start_autopilot_transition.connect(_on_autopilot_transition_start)
	SignalManager.end_autopilot_transition.connect(_on_exit_transition)
	SignalManager.autopilot_zoom_completed.connect(_on_zoom_complete)
	SignalManager.player_invincible.connect(_on_invincible)
	ItemManager.repair.connect(_on_repair_picked_up)

	# DRIVING
	max_backward_speed = roundi(player.unscaled_speed() * 0.8)
	friction = player.friction
	turn_speed = player.turn_speed
	velocity_floor = player.velocity_floor

	# COMPONENTS
	drift_manager.init_drift(self, player, rear_left, rear_right)
	burnout_manager.init_burnout(player, rear_left_burn_anim, rear_right_burn_anim)
	burnout_manager.rev_changed.connect(func(is_revving : bool) -> void: revving.emit(is_revving))
	burnout_manager.burnout_ended.connect(func() -> void: burnout_ok.emit(false))
	burnout_manager.burnout_launched.connect(func() -> void: dash_manager.try_dash())
	dash_manager.init_dash(self, player)
	burnout_manager.burnout_launched.connect(func() -> void: dash_manager.try_timed_dash())
	dash_manager.dash_started.connect(func() -> void: dashing.emit())
	dash_manager.dash_ended.connect(func() -> void: dash_end.emit())
	sprite_fx.init_fx(self, car_sprite, dash_manager)

	# FUEL
	bloody_engine.init_bloody_engine(player, car_sprite, dash_manager)

	# AUDIO
	start_engine.stream = player.start_engine_Sound  # per-car engine start sound
	dmg_players = [dmg_sfx, dmg_sfx_2, dmg_sfx_3]

	# VFX
	car_sprite.texture = player.car_sprite

	# LIFE
	if TimeManager.current_day == 1:
		player.current_life = int(player.max_life.get_value())
	emit_life_changed()

	if visible:
		engine_ignited.emit()
		start_engine.play()


func _physics_process(delta : float) -> void:
	if game_paused or !can_drive or game_is_over:
		return

	match autopilot_state:
		AutopilotState.NONE:
			_process_player_inputs(delta)
		AutopilotState.ZOOM:
			_process_autopilot_zoom(delta)
		AutopilotState.DRIVE:
			_process_autopilot_drive(delta)
		AutopilotState.EXIT:
			_process_autopilot_exit(delta)


func _process_player_inputs(delta : float) -> void:
	engine_sfx_player.update_engine_sfx(velocity.length(), burnout_manager.is_revving())
	update_skid_smokes()
	dash_manager.update_dash(delta)

	var forward : Vector2 = Vector2.RIGHT.rotated(rotation)
	var lateral : Vector2 = forward.rotated(PI / 2)

	# ----------------- INPUTS -----------------
	var throttle : float = Input.get_action_strength("accelerate")
	if throttle == 0.0:
		throttle = -Input.get_action_strength("back")
	var steer : float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	drifting = Input.is_action_pressed("drift") and throttle > 0.0

	if forward_only:
		throttle = maxf(throttle, 0.0)
		steer = 0.0
		drifting = false

	player.drifting = drifting

	# ----------------- BURNOUT / REV -----------------
	throttle = burnout_manager.process_burnout(delta, throttle, velocity.length())

	# ----------------- ACCELERATION -----------------
	if throttle != 0.0:
		velocity += forward * throttle * player.acceleration.get_value() * delta
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	velocity = velocity.limit_length(player.unscaled_speed())
	if throttle < 0.0:
		velocity = velocity.limit_length(max_backward_speed)

	# ----------------- ROTATION -----------------
	var speed : float = velocity.dot(forward)
	var steer_factor : float = clamp(abs(speed) / player.unscaled_speed(), MIN_STEER_FACTOR, 1.0)

	if drifting:
		steer *= player.drift_turn_bonus.get_value()
	elif drift_manager.is_sliding():
		# Auto-slide behaves like a lighter manual drift:
		# extra rotation + low grip -> the rear steps out and the car takes an angle
		steer *= drift_manager.get_slide_turn_bonus()

	rotation += steer * turn_speed * steer_factor * delta

	var forward_velocity : Vector2 = forward * velocity.dot(forward)
	var lateral_velocity : Vector2 = lateral * velocity.dot(lateral)

	velocity = drift_manager.update_drift(delta, drifting, forward_velocity, lateral_velocity, forward, velocity)

	# ----------------- COLLISION -----------------
	var motion : Vector2 = velocity * delta
	var collision : KinematicCollision2D = move_and_collide(motion)
	if collision:
		var collider : Node = collision.get_collider() as Node
		if collider and collider.is_in_group("walls"):
			_handle_wall_collision(collision, forward, delta)

	# ----------------- VFX -----------------
	if Input.is_action_just_pressed("accelerate") \
		or Input.is_action_just_pressed("move_left") \
		or Input.is_action_just_pressed("move_right"):
		play_drivin_smokes()


func _handle_wall_collision(collision : KinematicCollision2D, forward : Vector2, delta : float) -> void:
	var n : Vector2 = collision.get_normal().normalized()

	# Speed component going into the wall (before damping)
	var impact_speed : float = maxf(-velocity.dot(n), 0.0)
	if impact_speed >= WALL_IMPACT_MIN_SPEED:
		wall_impact.emit(impact_speed)

	velocity = velocity.slide(n) * WALL_BOUNCE_DAMP

	var wall_tan : Vector2 = Vector2(-n.y, n.x)
	var is_moving_forward : bool = velocity.dot(forward) > 0.0
	if velocity.dot(wall_tan) < 0.0:
		wall_tan = -wall_tan

	var new_speed : float = velocity.length()
	velocity = velocity.normalized().lerp(wall_tan, WALL_ALIGN_LERP) * new_speed

	var target_rotation : float = wall_tan.angle()
	if !is_moving_forward:
		target_rotation += PI
	rotation = lerp_angle(rotation, target_rotation, WALL_ROTATION_SPEED * delta)

	if drifting:
		SignalManager.wall_collision.emit()
		drifting = false
		drift_manager.force_stop_skid()


# ---------------- AUTOPILOT ----------------
func _process_autopilot_zoom(delta : float) -> void:
	var forward : Vector2 = Vector2.RIGHT.rotated(rotation)
	velocity = velocity.move_toward(forward * player.unscaled_speed(), 60.0 * delta)
	move_and_collide(velocity * delta)
	engine_sfx_player.update_engine_sfx(velocity.length(), false)


func _process_autopilot_drive(delta : float) -> void:
	rotation = lerp_angle(rotation, 0.0, 3.0 * delta)
	autopilot_speed = move_toward(autopilot_speed, player.unscaled_speed(), player.acceleration.get_value() * delta)
	velocity = (Vector2.RIGHT * autopilot_speed).limit_length(player.unscaled_speed())
	move_and_collide(velocity * delta)
	engine_sfx_player.update_engine_sfx(velocity.length(), false)


func _process_autopilot_exit(delta : float) -> void:
	rotation = lerp_angle(rotation, 0.0, 5.0 * delta)
	autopilot_speed += autopilot_exit_accel * delta
	velocity = (Vector2.RIGHT * autopilot_speed).limit_length(player.unscaled_speed() + 30.0)
	move_and_collide(velocity * delta)
	engine_sfx_player.update_engine_sfx(velocity.length(), false)


func _on_autopilot_transition_start() -> void:
	autopilot_state = AutopilotState.ZOOM
	autopilot_speed = velocity.length()

func _on_zoom_complete() -> void:
	autopilot_state = AutopilotState.DRIVE


func _on_exit_transition() -> void:
	autopilot_state = AutopilotState.EXIT
	await get_tree().create_timer(2.0).timeout
	SceneManager.load_level(SceneManager.SCENES.ROADMAP)


# ---------------- DAMAGES / LIFE ----------------
func get_damages_from_mob(damages_on_player : int) -> void:
	if player.invincible or game_paused or game_is_over:
		return
	if velocity.length() >= velocity_floor:
		return

	is_taking_damages = true
	player.current_life = maxi(player.current_life - damages_on_player, 0)
	sparkles.emitting = true
	damages_sfx()
	flash.play("flash")
	taking_damages.start()
	emit_life_changed()

	if player.current_life <= 0:
		on_death()


func get_damages(damages_on_player : int) -> void:
	if player.invincible or game_paused or game_is_over:
		return

	player.current_life = maxi(player.current_life - damages_on_player, 0)
	sparkles.emitting = true
	flash.play("flash")
	emit_life_changed()

	if player.current_life <= 0:
		on_death()


func emit_life_changed() -> void:
	SignalManager.player_life_changed.emit(player.current_life, int(player.max_life.get_value()))


func _on_repair_picked_up(repair_amount : int) -> void:
	player.current_life = mini(player.current_life + repair_amount, int(player.max_life.get_value()))
	emit_life_changed()


func on_death() -> void:
	can_drive = false
	is_taking_damages = false
	WeaponsManager.activate_weapons(false)
	dash_manager.end_dash()
	bloody_engine.set_process(false)
	car_sprite.modulate = Color.WHITE
	stop_invincibility_vfx()
	car_sprite.hide()
	drift_manager.force_stop_skid()
	collision_shape.set_deferred("disabled", true)
	car_explosion.play("Explosion")
	death_sfx.play()
	SignalManager.screen_shake_requested.emit(15.0, 1.0)
	game_is_over = true
	SignalManager.game_is_over.emit(game_is_over)
	await get_tree().create_timer(2).timeout
	queue_free()
	game_over.emit(game_is_over)


func _on_taking_damages_timeout() -> void:
	is_taking_damages = false


func _on_hitbox_area_entered(area : Area2D) -> void:
	if !game_paused and velocity.length() >= velocity_floor:
		if area.is_in_group("ennemies") and "get_damages_from_car" in area:
			area.get_damages_from_car(roundi(player.dmg.get_value()))
			StatsManager.total_car_dmg += roundi(player.dmg.get_value())


# ---------------- GAME STATE ----------------
func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause


func _on_start_engine_finished() -> void:
	can_drive = true
	start_time.emit(can_drive)
	SignalManager.start_timer.emit()
	WeaponsManager.activate_weapons(true)


func _on_full_command(full_command : bool) -> void:
	if !full_command:
		can_drive = false


func _on_forward_only(car_only_forward : bool) -> void:
	forward_only = car_only_forward


# ---------------- SFX / VFX HELPERS ----------------
func damages_sfx() -> void:
	if game_paused or game_is_over:
		return
	for dmg_player : AudioStreamPlayer in dmg_players:
		if !dmg_player.playing:
			dmg_player.play()
			return


func play_drivin_smokes() -> void:
	if game_paused or game_is_over:
		return
	drivin_smoke_r_2.emitting = true
	drivin_smoke_l_2.emitting = true


func update_skid_smokes() -> void:
	var skid_smoke : bool = enable_skid_smoke and (drifting or drift_manager.is_sliding())
	if skid_smoke:
		drivin_smoke_r_2.emitting = true
		drivin_smoke_l_2.emitting = true
	elif skid_smoke_active:
		drivin_smoke_r_2.emitting = false
		drivin_smoke_l_2.emitting = false
	skid_smoke_active = skid_smoke


func get_drift_factor() -> float:
	return drift_manager.get_drift_factor()


# ---------------- INVINCIBILITY ----------------
func _on_invincible(player_invincible : bool) -> void:
	if player_invincible:
		start_invincibility_vfx()
	else:
		stop_invincibility_vfx()


func start_invincibility_vfx() -> void:
	if glow_sprite == null:
		glow_sprite = Sprite2D.new()
		glow_sprite.offset = car_sprite.offset
		glow_sprite.flip_h = car_sprite.flip_h
		glow_sprite.flip_v = car_sprite.flip_v
		glow_sprite.texture = car_sprite.texture
		glow_sprite.light_mask = car_sprite.light_mask
		var mat : CanvasItemMaterial = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow_sprite.material = mat
		glow_sprite.z_index = car_sprite.z_index - 1
		car_sprite.add_child(glow_sprite)

	if invincibility_tween:
		invincibility_tween.kill()
	invincibility_tween = create_tween().set_loops()
	invincibility_tween.tween_property(glow_sprite, "modulate", Color(3.0, 2.5, 0.0, 1.0), 0.18).set_trans(Tween.TRANS_SINE)
	invincibility_tween.tween_property(glow_sprite, "modulate", Color(0.0, 0.0, 0.0, 0.0), 0.18).set_trans(Tween.TRANS_SINE)


func stop_invincibility_vfx() -> void:
	if invincibility_tween:
		invincibility_tween.kill()
		invincibility_tween = null
	if glow_sprite:
		glow_sprite.queue_free()
		glow_sprite = null

func _ready_debug() -> void:
	# Minimal init for map test scenes: driving only.
	# No weapons, no run flow, BloodyEngine off (it needs the World HUD/blood pool).
	player = debug_car_data if debug_car_data != null else CarManager.selected_car
	if player == null:
		push_error("[RigidCar] debug_drive_mode: no CarData (set debug_car_data in the inspector)")
		set_physics_process(false)
		return
	player.init_stats()

	# DRIVING
	max_backward_speed = roundi(player.unscaled_speed() * 0.8)
	friction = player.friction
	turn_speed = player.turn_speed
	velocity_floor = player.velocity_floor

	# COMPONENTS
	drift_manager.init_drift(self, player, rear_left, rear_right)
	burnout_manager.init_burnout(player, rear_left_burn_anim, rear_right_burn_anim)
	burnout_manager.burnout_launched.connect(func() -> void: dash_manager.try_dash())
	dash_manager.init_dash(self, player)
	sprite_fx.init_fx(self, car_sprite, dash_manager)


	# Free dash for testing: fuel and nitro always topped up
	player.current_fuel = int(player.max_fuel.get_value())
	player.current_nitro = 999999
	dash_manager.dash_ended.connect(func() -> void:
		player.current_fuel = int(player.max_fuel.get_value())
		player.current_nitro = 999999
	)

	# VFX / AUDIO / LIFE
	car_sprite.texture = player.car_sprite
	dmg_players = [dmg_sfx, dmg_sfx_2, dmg_sfx_3]
	player.current_life = int(player.max_life.get_value())

	can_drive = true  # no engine-start sound gate in debug
