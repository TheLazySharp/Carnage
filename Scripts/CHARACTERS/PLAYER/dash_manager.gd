extends Node2D
class_name DashManager

signal dash_anticipating
signal dash_started
signal dash_ended

@export var enable_input_buffer : bool = true
@export var enable_anticipation : bool = true
@export var enable_ghost : bool = true
@export var enable_hitstop : bool = true

const DASH_BUFFER_TIME : float = 0.15
const ANTICIPATION_TIME : float = 0.09      # seconds real time before propulsion
const HITSTOP_SCALE : float = 0.08
const HITSTOP_DURATION : float = 0.08       # seconds real time (ignore time_scale)
const DASH_FRICTION : float = 10.0
const DASH_SPEED_MULT : float = 1.25
const DASH_TORQUE_MULT : float = 2.0
const GHOST_INTERVAL : float = 0.05

# ---------------- SUSTAINED BOOST (NFSU2 style) ----------------
const NITRO_TICK_TIME : float = 0.3        # seconds between two nitro units
const NITRO_TICK_COST : int = 10             # nitro units burnt per tick
const MIN_NITRO_TO_START : int = 10         # nitro needed to ignite. Set to max_nitro for a "full gauge only" rule
const MIN_BOOST_TIME : float = 0.12         # floor duration so a tap still feels good
const BOOST_ACCEL : float = 900.0           # continuous forward push while held
const DASH_ACTION : StringName = &"dash"

const MOD_DMG : String = "dmg_dash_bonus"
const MOD_SPEED : String = "max_speed_dash_modifier"
const MOD_TORQUE : String = "torque_dash_modifier"

@export var ghost_scene : PackedScene

var car : CharacterBody2D
var player : CarData

var is_dashing : bool = false
var is_preparing : bool = false
var is_sustained : bool = false             # true = held by input, false = fixed duration (burnout launch)
var dash_timer : float = 0.0                # fixed duration path only
var boost_time : float = 0.0                # elapsed boost time, drives MIN_BOOST_TIME
var nitro_timer : float = 0.0
var buffer_timer : float = 0.0
var original_friction : float = 0.0
var ghost_timer : Timer


func _ready() -> void:
	ghost_timer = Timer.new()
	ghost_timer.wait_time = GHOST_INTERVAL
	ghost_timer.timeout.connect(_spawn_ghost)
	add_child(ghost_timer)


func init_dash(p_car : CharacterBody2D, data : CarData) -> void:
	car = p_car
	player = data


## Called on input press : the boost is held until the key is released
func try_dash() -> void:
	if !dash_available():
		if enable_input_buffer:
			buffer_timer = DASH_BUFFER_TIME
		return
	execute_dash(true)


## Called by the burnout launch : no key is held, so fall back to a fixed duration
func try_timed_dash() -> void:
	if !dash_available():
		return
	execute_dash(false)


func dash_available() -> bool:
	return !is_dashing \
		and !is_preparing \
		and player.current_fuel >= player.dash_fuel_down \
		and player.current_nitro >= MIN_NITRO_TO_START


## called from car physics process
func update_dash(delta : float) -> void:
	# Input buffer : replay the held press as soon as dashing becomes possible again
	if buffer_timer > 0.0:
		buffer_timer -= delta
		if dash_available():
			buffer_timer = 0.0
			execute_dash(true)

	if !is_dashing:
		return

	boost_time += delta

	# Continuous forward push. The car script clamps velocity to unscaled_speed()
	# right after this call, so the boosted max_speed modifier is what caps it.
	car.velocity += Vector2.RIGHT.rotated(car.rotation) * BOOST_ACCEL * delta

	if is_sustained:
		nitro_timer -= delta
		if nitro_timer <= 0.0:
			nitro_timer += NITRO_TICK_TIME
			if !consume_nitro():
				end_dash()
				return
		if boost_time >= MIN_BOOST_TIME and !Input.is_action_pressed(DASH_ACTION):
			end_dash()
	else:
		dash_timer -= delta
		if dash_timer <= 0.0:
			end_dash()


func execute_dash(p_sustained : bool) -> void:
	buffer_timer = 0.0

	if enable_anticipation:
		is_preparing = true
		dash_anticipating.emit()
		await get_tree().create_timer(ANTICIPATION_TIME, true, false, true).timeout
		is_preparing = false
		if !is_instance_valid(car) or car.game_is_over:
			return

	is_sustained = p_sustained
	boost_time = 0.0
	nitro_timer = NITRO_TICK_TIME

	dash_started.emit()
	if enable_hitstop:
		hitstop()
	SignalManager.screen_shake_requested.emit(12.0, 0.4)

	consume_nitro()

	player.dmg.add_modifier(Modifier.new(player.dash_dmg_bonus.get_value(), Modifier.Type.PERCENT_MULT, MOD_DMG))
	player.max_speed.add_modifier(Modifier.new(DASH_SPEED_MULT, Modifier.Type.PERCENT_MULT, MOD_SPEED))
	player.acceleration.add_modifier(Modifier.new(DASH_TORQUE_MULT, Modifier.Type.PERCENT_MULT, MOD_TORQUE))

	car.velocity += Vector2.RIGHT.rotated(car.rotation) * player.unscaled_speed()

	original_friction = car.friction
	car.friction = DASH_FRICTION
	dash_timer = player.dash_duration.get_value()
	is_dashing = true
	if enable_ghost:
		ghost_timer.start()


func end_dash() -> void:
	if !is_dashing:
		return
	is_dashing = false
	is_sustained = false
	dash_timer = 0.0
	boost_time = 0.0

	player.dmg.remove_modifiers_from(MOD_DMG)
	player.max_speed.remove_modifiers_from(MOD_SPEED)
	player.acceleration.remove_modifiers_from(MOD_TORQUE)

	car.friction = original_friction
	ghost_timer.stop()
	dash_ended.emit()


func consume_nitro() -> bool:
	player.current_nitro = maxi(player.current_nitro - NITRO_TICK_COST, 0)
	SignalManager.nitro_changed.emit(player.current_nitro)
	return player.current_nitro >= NITRO_TICK_COST


func hitstop() -> void:
	Engine.time_scale = HITSTOP_SCALE
	await get_tree().create_timer(HITSTOP_DURATION, true, false, true).timeout
	Engine.time_scale = 1.0


func _spawn_ghost() -> void:
	if ghost_scene == null or !is_instance_valid(car):
		return
	var ghost : Node2D = ghost_scene.instantiate()
	ghost.set_property(car.position, car.scale, car.rotation)
	get_tree().current_scene.add_child(ghost)
