extends Node2D

signal grenade_landed(world_position : Vector2)

@export var grenade_data : WeaponData

@export_group("THROW")
## Average travel distance from the launch point, in pixels
@export var throw_distance : float = 150.0
## Random +/- applied to throw_distance
@export var throw_distance_random : float = 25.0
## Flight duration, in seconds
@export var throw_duration : float = 0.7
## Random +/- applied to throw_duration
@export var throw_duration_random : float = 0.08

@export_group("LANDING")
## Radius that must be clear of buildings around the landing spot, in pixels
@export var landing_clearance : float = 14.0
## Random directions tried before giving up and dropping the grenade short
@export var landing_attempts : int = 8

@export_group("FLIGHT FX")
## Full turns the sprite makes while airborne (direction is randomized)
@export var spin_turns : float = 2.0
## Sprite scale multiplier at the top of the arc (fakes height)
@export var arc_peak_scale : float = 1.9
## Extra upward sprite offset at the top of the arc, in pixels
@export var arc_peak_lift : float = 18.0

@onready var _sprite : Sprite2D = $Icon

var _start_position : Vector2 = Vector2.ZERO
var _target_position : Vector2 = Vector2.ZERO
var _sprite_base_scale : Vector2 = Vector2.ONE
var _spin_amount : float = 0.0
var _flight_duration : float = 0.0
var _launch_pending : bool = false

@onready var _flow_field: FlowFieldManager = $/root/World/FlowFieldManager


func _ready() -> void:
	_sprite_base_scale = _sprite.scale

	# Same wall grid the enemies path on: a spot that is free here is always
	# reachable by the horde. Read only, safe while a rebuild task is in flight.

	if _flow_field == null:
		push_warning("Grenade: no FlowFieldManager in group 'flow_field', landing spots are not checked")

	# The launcher may have called launch_grenade() before add_child()
	if _launch_pending:
		_launch_pending = false
		_start_flight()


## Called by the launcher. from_pos is the car global_position.
func launch_grenade(from_pos : Vector2) -> void:
	_start_position = from_pos
	global_position = from_pos

	_spin_amount = spin_turns * TAU * (1.0 if randf() < 0.5 else -1.0)
	_flight_duration = maxf(0.05, throw_duration \
		+ randf_range(-throw_duration_random, throw_duration_random))

	# The target needs the physics world: defer until we are in the tree
	if not is_inside_tree():
		_launch_pending = true
		return
	_start_flight()


func _start_flight() -> void:
	_target_position = _pick_landing_position(_start_position)
	var tween : Tween = create_tween()
	tween.tween_method(_apply_flight, 0.0, 1.0, _flight_duration)
	tween.tween_callback(_on_grenade_landed)

## Random direction around the launcher, rejected until the spot is clear of
## buildings. Each retry pulls the throw a bit shorter, so a grenade thrown at
## a facade lands in front of it instead of inside it.
func _pick_landing_position(from_pos : Vector2) -> Vector2:
	var base_distance : float = maxf(8.0, throw_distance \
		+ randf_range(-throw_distance_random, throw_distance_random))

	# No grid yet (debug scene, or thrown before map_generated): throw blind
	if _flow_field == null or not _flow_field.field_ready:
		var blind_angle : float = randf() * TAU
		return from_pos + Vector2(cos(blind_angle), sin(blind_angle)) * base_distance

	for attempt : int in landing_attempts:
		var angle : float = randf() * TAU
		var distance : float = maxf(landing_clearance, \
			base_distance * (1.0 - 0.1 * float(attempt)))
		var candidate : Vector2 = from_pos + Vector2(cos(angle), sin(angle)) * distance
		if _is_landing_clear(candidate):
			return candidate

	# Built up all around: drop it at the launcher's feet, a drivable cell by
	# definition.
	return from_pos


## Center cell plus four cardinal probes at landing_clearance: five array reads,
## zero allocation. is_blocked_world() already returns true outside the map, so
## the map border needs no separate test.
func _is_landing_clear(world_pos : Vector2) -> bool:
	if _flow_field.is_blocked_world(world_pos):
		return false
	if _flow_field.is_blocked_world(world_pos + Vector2(landing_clearance, 0.0)):
		return false
	if _flow_field.is_blocked_world(world_pos - Vector2(landing_clearance, 0.0)):
		return false
	if _flow_field.is_blocked_world(world_pos + Vector2(0.0, landing_clearance)):
		return false
	if _flow_field.is_blocked_world(world_pos - Vector2(0.0, landing_clearance)):
		return false
	return true

## One callback per frame drives the whole throw. sin(ratio * PI) gives
## 0 -> 1 -> 0: the perceived height of the grenade above the ground.
func _apply_flight(ratio : float) -> void:
	global_position = _start_position.lerp(_target_position, ratio)
	var height : float = sin(ratio * PI)
	_sprite.rotation = _spin_amount * ratio
	_sprite.scale = _sprite_base_scale * (1.0 + (arc_peak_scale - 1.0) * height)
	_sprite.position.y = -arc_peak_lift * height


## Landing: sprite back to its resting state, then hand over to the explosion.
func _on_grenade_landed() -> void:
	_sprite.rotation = 0.0
	_sprite.scale = _sprite_base_scale
	_sprite.position = Vector2.ZERO
	grenade_landed.emit(global_position)
	# TODO: explosion / fuse timer here
