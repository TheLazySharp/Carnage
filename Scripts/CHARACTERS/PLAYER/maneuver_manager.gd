extends Node
class_name ManeuverManager

enum Type { SHORT_DRIFT, DRIFT_U_TURN, DONUT, LOOP, REVERSE_U_TURN, BURNOUT, HORN, SPIN_360 }
# Display names, in the order of Type
const MANEUVER_NAMES: PackedStringArray = [
	"QUICK DRIFT", "DRIFT U-TURN", "DONUT", "LOOP",
	"REVERSE 180", "BURNOUT", "HORN", "360",
]

@onready var car: CharacterBody2D = $".."
@onready var burnout_manager: BurnoutManager = $"../BurnoutManager"
@onready var dash_manager: DashManager = $"../DashManager"
@onready var drift_manager: Node2D = $"../DriftManager"
@onready var rear_left: Marker2D = $"../RearLeft"
@onready var rear_right: Marker2D = $"../RearRight"

@export_group("Inputs")
@export var drift_action: StringName = &"drift"
@export var throttle_action: StringName = &"accelerate"
@export var brake_action: StringName = &"brake"
@export var horn_action: StringName = &"horn"
# Car sprite forward axis in local space (Vector2.UP if the sprite points up)
@export var local_forward: Vector2 = Vector2.RIGHT

@export_group("General")
# Speed used to normalize speed-based intensities (roughly the car top speed)
@export var reference_speed: float = 600.0
# Below this speed the car is considered spinning in place: slip counts as 90 degrees
@export var slip_min_speed: float = 30.0

@export_group("Short drift")
@export var short_drift_max_duration: float = 0.4
# Shorter drifts are ignored (prevents button spamming)
@export var short_drift_min_duration: float = 0.15
@export var short_drift_min_slip_degrees: float = 20.0
@export var short_drift_min_speed: float = 200.0

@export_group("U-turns")
@export var u_turn_min_degrees: float = 150.0
@export var drift_u_turn_max_duration: float = 1.2
# Min backward speed when the reverse turns into a drift (a stopped car is not reversing)
@export var reverse_min_speed: float = 30.0
# Max delay between the end of the reverse and the end of the turn
@export var reverse_turn_window: float = 0.8


@export_group("360")
@export_range(270.0, 360.0) var spin_360_min_degrees: float = 340.0
@export var spin_360_max_duration: float = 2.0

@export_group("Donut")
@export_range(270.0, 360.0) var donut_turn_degrees: float = 340.0
@export var donut_max_duration: float = 1.5
@export var donut_min_average_slip_degrees: float = 50.0
# A single turn followed by a release is a 360: the donut needs consecutive turns
@export var donut_min_turns: int = 2
var donut_turn_count: int = 0

@export_group("Burnout")
@export var steer_left_action: StringName = &"move_left"
@export var steer_right_action: StringName = &"move_right"
# Above this steering, the rev is a donut attempt, not a burnout
@export_range(0.0, 1.0) var burnout_max_steer: float = 0.2

@export_group("Loop")
@export var loop_sample_distance: float = 25.0
var spin_360_min_angle: float
# Trail points older than this (seconds) can no longer close a loop
@export var loop_max_age: float = 3.0
@export var loop_min_perimeter: float = 300.0


# Thresholds converted once
var short_drift_min_slip: float
var u_turn_min_angle: float
var donut_turn_angle: float
var donut_min_average_slip: float
var loop_sample_distance_squared: float

var game_paused: bool = false
var previous_heading: float = 0.0

# Drift session state
var in_drift_session: bool = false
var drift_session_consumed: bool = false
var drift_duration: float = 0.0
var drift_max_slip: float = 0.0
var drift_entry_speed: float = 0.0
# Signed heading rotation over the whole session
var drift_rotation: float = 0.0
# Highest drift charge tier reached during the session (the DriftManager resets it on release)
var drift_level: int = 0

# Donut state
var donut_rotation: float = 0.0
var donut_slip_time_sum: float = 0.0
var donut_time: float = 0.0

# Loop trail (positions and timestamps in drift session time)
var trail_points: PackedVector2Array = PackedVector2Array()
var trail_times: PackedFloat32Array = PackedFloat32Array()
var trail_start: int = 0
# Last closed loop, kept for the weapons step
var loop_polygon: PackedVector2Array = PackedVector2Array()

# Reverse U-turn state
var reverse_heading: float = 0.0
var reverse_speed: float = 0.0
var reverse_window_left: float = 0.0
# Previous frame state: drift key held without throttle (reverse)
var was_reversing: bool = false


func _ready() -> void:
	short_drift_min_slip = deg_to_rad(short_drift_min_slip_degrees)
	u_turn_min_angle = deg_to_rad(u_turn_min_degrees)
	donut_turn_angle = deg_to_rad(donut_turn_degrees)
	donut_min_average_slip = deg_to_rad(donut_min_average_slip_degrees)
	loop_sample_distance_squared = loop_sample_distance * loop_sample_distance
	spin_360_min_angle = deg_to_rad(spin_360_min_degrees)
	previous_heading = car.global_rotation
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.wall_collision.connect(_on_wall_collision)
	burnout_manager.burnout_charged.connect(_on_burnout_charged)


func _on_game_paused(game_on_pause: bool) -> void:
	game_paused = game_on_pause

func _on_wall_collision() -> void:
	# A drift killed by a wall is a failed drift: no maneuver on release
	if in_drift_session:
		drift_session_consumed = true

func _on_burnout_charged() -> void:
	# A rev while steering is a donut attempt, not a burnout
	if absf(Input.get_axis(steer_left_action, steer_right_action)) > burnout_max_steer:
		return
	# The rev holds drift + throttle, so a drift session is running:
	# consuming it prevents an extra maneuver when the burnout is launched
	if in_drift_session:
		if drift_session_consumed:
			return
		drift_session_consumed = true
	_emit_maneuver(Type.BURNOUT, 1.0)

func _physics_process(delta: float) -> void:
	if game_paused:
		return
	var velocity: Vector2 = car.velocity
	var speed: float = velocity.length()
	var heading: float = car.global_rotation
	var heading_delta: float = wrapf(heading - previous_heading, -PI, PI)
	previous_heading = heading
	var forward: Vector2 = local_forward.rotated(heading)
	var forward_speed: float = forward.dot(velocity)

	# Drift state comes from the car itself (handles the wall lock and forward-only mode)
	var drifting: bool = car.drifting
	if drifting and not in_drift_session:
		_start_drift_session(speed, heading, forward_speed)
	elif not drifting and in_drift_session:
		_end_drift_session()
	# Reverse: back pressed without throttle (same rule as rigid_car)
	was_reversing = Input.is_action_pressed(brake_action) and not Input.is_action_pressed(throttle_action)

	if in_drift_session:
		var slip: float = PI * 0.5
		if speed > slip_min_speed:
			slip = absf(forward.angle_to(velocity))
		_update_drift_session(delta, slip, heading_delta)
		_update_donut(delta, slip, heading_delta)
		_update_loop()

	_update_reverse_u_turn(delta, heading, forward_speed)

	if Input.is_action_just_pressed(horn_action):
		_emit_maneuver(Type.HORN, speed / reference_speed)


# --- Drift session ---

func _start_drift_session(speed: float, heading: float, forward_speed: float) -> void:
	in_drift_session = true
	drift_session_consumed = false
	drift_duration = 0.0
	drift_max_slip = 0.0
	drift_entry_speed = speed
	drift_rotation = 0.0
	drift_level = 0
	donut_turn_count = 0
	_reset_donut()
	trail_points.clear()
	trail_times.clear()
	trail_start = 0
	trail_points.append(_get_trail_position())
	trail_times.append(0.0)
	# Reverse turned into a drift (throttle pressed while reversing):
	# arm the reverse U-turn from this heading, whatever the reverse duration.
	# This drift can only end as a reverse U-turn (no release maneuver).
	if was_reversing and forward_speed <= -reverse_min_speed:
		reverse_heading = heading
		reverse_speed = absf(forward_speed)
		reverse_window_left = reverse_turn_window
		drift_session_consumed = true


func _update_drift_session(delta: float, slip: float, heading_delta: float) -> void:
	drift_duration += delta
	drift_max_slip = maxf(drift_max_slip, slip)
	drift_rotation += heading_delta
	drift_level = maxi(drift_level, int(drift_manager.charge_tier))


func _end_drift_session() -> void:
	in_drift_session = false
	if drift_session_consumed:
		return
	var rotation_abs: float = absf(drift_rotation)
	if rotation_abs >= spin_360_min_angle and drift_duration <= spin_360_max_duration:
		_emit_maneuver(Type.SPIN_360, drift_entry_speed / reference_speed)
	elif rotation_abs >= u_turn_min_angle and rotation_abs < spin_360_min_angle \
			and drift_duration <= drift_u_turn_max_duration:
		_emit_maneuver(Type.DRIFT_U_TURN, drift_entry_speed / reference_speed)
	elif drift_duration >= short_drift_min_duration \
			and drift_duration <= short_drift_max_duration \
			and drift_max_slip >= short_drift_min_slip \
			and drift_entry_speed >= short_drift_min_speed:
		_emit_maneuver(Type.SHORT_DRIFT, drift_max_slip / (PI * 0.5))


# --- Donut ---

func _update_donut(delta: float, slip: float, heading_delta: float) -> void:
	donut_rotation += heading_delta
	donut_slip_time_sum += slip * delta
	donut_time += delta
	if donut_time > donut_max_duration:
		# Too slow for a donut: the chain of turns is broken
		donut_turn_count = 0
		_reset_donut()
		return
	if absf(donut_rotation) < donut_turn_angle:
		return
	if donut_slip_time_sum / donut_time < donut_min_average_slip:
		donut_turn_count = 0
		_reset_donut()
		return
	donut_turn_count += 1
	if donut_turn_count >= donut_min_turns:
		drift_session_consumed = true
		# 1.0 when the turn takes half the max duration
		_emit_maneuver(Type.DONUT, donut_max_duration * 0.5 / donut_time)
	_reset_donut()


func _reset_donut() -> void:
	donut_rotation = 0.0
	donut_slip_time_sum = 0.0
	donut_time = 0.0


# --- Loop ---

func _update_loop() -> void:
	var car_position: Vector2 = _get_trail_position()
	var last_index: int = trail_points.size() - 1
	if car_position.distance_squared_to(trail_points[last_index]) < loop_sample_distance_squared:
		return
	# Forget points older than the max age
	var oldest_time: float = drift_duration - loop_max_age
	while trail_start < last_index and trail_times[trail_start] < oldest_time:
		trail_start += 1
	# Test the new segment against older ones, oldest first (biggest loop first).
	# The last segment shares a point with the new one, so it is skipped.
	var segment_start: Vector2 = trail_points[last_index]
	for index: int in range(trail_start, last_index - 1):
		var crossing: Variant = Geometry2D.segment_intersects_segment(
				segment_start, car_position, trail_points[index], trail_points[index + 1])
		if crossing == null:
			continue
		if _try_close_loop(index, crossing, car_position):
			return
		# Newer crossings would make even smaller loops
		break
	trail_points.append(car_position)
	trail_times.append(drift_duration)

## Rear axle center: where both rear skid marks overlap, i.e. the trace the player sees
func _get_trail_position() -> Vector2:
	return (rear_left.global_position + rear_right.global_position) * 0.5
	
func _try_close_loop(crossed_index: int, crossing: Vector2, car_position: Vector2) -> bool:
	var last_index: int = trail_points.size() - 1
	# Loop path: crossing -> points after the crossed segment -> back to crossing
	var perimeter: float = crossing.distance_to(trail_points[crossed_index + 1]) \
			+ trail_points[last_index].distance_to(crossing)
	for point_index: int in range(crossed_index + 1, last_index):
		perimeter += trail_points[point_index].distance_to(trail_points[point_index + 1])
	# DEBUG: a crossing was found, check its size
	if perimeter < loop_min_perimeter:
		return false
	loop_polygon = trail_points.slice(crossed_index + 1, last_index + 1)
	loop_polygon.append(crossing)
	drift_session_consumed = true
	# 1.0 for the biggest loop the max age allows at reference speed
	_emit_maneuver(Type.LOOP, perimeter / (reference_speed * loop_max_age))
	# Start a fresh trail so the same loop cannot close twice
	trail_points.clear()
	trail_times.clear()
	trail_start = 0
	trail_points.append(car_position)
	trail_times.append(drift_duration)
	return true


# --- Reverse U-turn ---

func _update_reverse_u_turn(delta: float, heading: float, forward_speed: float) -> void:
	if reverse_window_left <= 0.0:
		return
	reverse_window_left -= delta
	if forward_speed > 0.0 and absf(wrapf(heading - reverse_heading, -PI, PI)) >= u_turn_min_angle:
		reverse_window_left = 0.0
		_emit_maneuver(Type.REVERSE_U_TURN, reverse_speed / reference_speed)


func _emit_maneuver(maneuver_type: Type, intensity: float) -> void:
	# Not owned yet: feedback only, no weapon, no combo
	if !LoadoutManager.owns(maneuver_type):
		SignalManager.maneuver_locked.emit(maneuver_type)
		return
	# Drift level only applies to drift maneuvers
	var level: int = drift_level
	if maneuver_type == Type.HORN or maneuver_type == Type.BURNOUT:
		level = 0
	# World-space attack direction: car heading + the pattern offset
	var direction_offset: float = get_pattern(maneuver_type).x
	if maneuver_type == Type.SHORT_DRIFT:
		# Outer side of the turn: rotation > 0 = clockwise = right turn -> left side
		direction_offset = -PI * 0.5 if drift_rotation > 0.0 else PI * 0.5
	var attack_angle: float = car.global_rotation + direction_offset
	# Amplified if the dash is active when the maneuver completes
	SignalManager.maneuver_performed.emit(maneuver_type, clampf(intensity, 0.0, 1.0), level, dash_manager.is_dashing, attack_angle)

## Attack shape per maneuver, shared by every weapon:
## x = direction (radians, relative to the car heading), y = arc (radians), z = duration (seconds).
## z < 0 = no projectile pattern (zone maneuvers)
static func get_pattern(maneuver_type: Type) -> Vector3:
	match maneuver_type:
		Type.SHORT_DRIFT:
			return Vector3(0.0, deg_to_rad(100.0), 0.25)  # direction resolved on emit (outer side)
		Type.DRIFT_U_TURN, Type.REVERSE_U_TURN:
			# Both U-turns hit what the car just turned its back on
			return Vector3(PI, PI, 0.3)
		Type.SPIN_360:
			return Vector3(0.0, TAU, 0.4)
		Type.DONUT:
			return Vector3(0.0, TAU, 0.6)
		Type.HORN:
			return Vector3(0.0, deg_to_rad(30.0), 0.1)
		Type.BURNOUT:
			return Vector3(PI, deg_to_rad(50.0), 0.4)
	# LOOP: zone attack, no projectile pattern
	return Vector3(0.0, 0.0, -1.0)


## Risk reward per maneuver: projectile count multiplier on top of the shape
static func get_power(maneuver_type: Type) -> float:
	match maneuver_type:
		Type.REVERSE_U_TURN:
			return 2.0  # risky: reversing into the horde
	return 1.0

static func get_maneuver_name(maneuver_type: Type) -> String:
	return MANEUVER_NAMES[maneuver_type]


## World angle of shot `index` among `count` spread over `arc` around `center`.
## A full circle is spread evenly without doubling the first and last shot
static func get_spread_angle(index: int, count: int, arc: float, center: float) -> float:
	if arc >= TAU - 0.01:
		return center + TAU * index / count
	if count <= 1:
		return center
	return center - arc * 0.5 + arc * index / (count - 1)
