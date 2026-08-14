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
const ANTICIPATION_TIME : float = 0.09      # secondes real time before propulsion
const HITSTOP_SCALE : float = 0.08
const HITSTOP_DURATION : float = 0.08       # secondes real itme (ignore time_scale)
const DASH_FRICTION : float = 10.0
const DASH_SPEED_MULT : float = 1.25
const DASH_TORQUE_MULT : float = 2.0
const GHOST_INTERVAL : float = 0.05

@export var ghost_scene : PackedScene

var car : CharacterBody2D
var player : CarData

var can_dash : bool = false
var is_dashing : bool = false
var is_preparing : bool = false
var dash_timer : float = 0.0
var buffer_timer : float = 0.0
var original_friction : float = 0.0
var ghost_timer : Timer


func _ready() -> void:
	SignalManager.boost_gauge_is_full.connect(_on_boost_full)
	ghost_timer = Timer.new()
	ghost_timer.wait_time = GHOST_INTERVAL
	ghost_timer.timeout.connect(_spawn_ghost)
	add_child(ghost_timer)


func init_dash(p_car : CharacterBody2D, data : CarData) -> void:
	car = p_car
	player = data


func try_dash() -> void:
	if !_dash_available():
		if enable_input_buffer:
			buffer_timer = DASH_BUFFER_TIME
		return
	_execute_dash()


func _dash_available() -> bool:
	return can_dash and !is_dashing and !is_preparing \
		and player.current_fuel >= player.dash_fuel_down


## called from car physics process
func update_dash(delta : float) -> void:
	# Input buffer : retente l'appui retenu dès que le dash redevient possible
	if buffer_timer > 0.0:
		buffer_timer -= delta
		if _dash_available():
			buffer_timer = 0.0
			_execute_dash()

	if !is_dashing:
		return
	dash_timer -= delta
	if dash_timer <= 0.0:
		end_dash()


func _execute_dash() -> void:
	can_dash = false
	buffer_timer = 0.0

	if enable_anticipation:
		is_preparing = true
		dash_anticipating.emit()
		await get_tree().create_timer(ANTICIPATION_TIME, true, false, true).timeout
		is_preparing = false
		if !is_instance_valid(car) or car.game_is_over:
			return

	dash_started.emit()
	if enable_hitstop:
		hitstop()
	SignalManager.screen_shake_requested.emit(12.0, 0.4)

	var duration : float = player.dash_duration.get_value()
	player.dmg.add_temp_modifier(Modifier.new(player.dash_dmg_bonus.get_value(), Modifier.Type.PERCENT_MULT, "dmg_dash_bonus", duration))
	player.max_speed.add_temp_modifier(Modifier.new(DASH_SPEED_MULT, Modifier.Type.PERCENT_MULT, "max_speed_dash_modifier", duration))
	player.acceleration.add_temp_modifier(Modifier.new(DASH_TORQUE_MULT, Modifier.Type.PERCENT_MULT, "torque_dash_modifier", duration))

	var forward : Vector2 = Vector2.RIGHT.rotated(car.rotation)
	car.velocity += forward * player.unscaled_speed()

	original_friction = car.friction
	car.friction = DASH_FRICTION
	dash_timer = duration
	is_dashing = true
	if enable_ghost:
		ghost_timer.start()


func end_dash() -> void:
	if !is_dashing:
		return
	is_dashing = false
	dash_timer = 0.0
	car.friction = original_friction
	ghost_timer.stop()
	dash_ended.emit()


func hitstop() -> void:
	Engine.time_scale = HITSTOP_SCALE
	await get_tree().create_timer(HITSTOP_DURATION, true, false, true).timeout
	Engine.time_scale = 1.0


func _on_boost_full() -> void:
	can_dash = true


func _spawn_ghost() -> void:
	if ghost_scene == null or !is_instance_valid(car):
		return
	var ghost : Node2D = ghost_scene.instantiate()
	ghost.set_property(car.position, car.scale, car.rotation)
	get_tree().current_scene.add_child(ghost)
