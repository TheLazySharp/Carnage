extends State
class_name EnemyIdle

@onready var enemy: Enemy = self.get_parent().get_parent()
@onready var day_manager: Node = $/root/World/DayManager

## Used when the EnemyData has no idle_flocking profile.
@export var default_flocking: FlockingProfile = null
## Troupers walk toward the leader only when farther than this (px). Inside, the pack just settles.
## ~90 px fits a 60-enemy horde with a 22 px separation.
@export var pack_radius: float = 90.0
## Speed ratio of the small corrections inside the pack: slow = calm, no overshoot.
@export_range(0.1, 1.0, 0.05) var settle_speed_ratio: float = 0.35
## Trouper steering refresh interval (s, min / max).
@export var update_interval_range: Vector2 = Vector2(0.25, 0.4)
## Leader wander speed ratio: below 1 so troupers can keep up and stay packed.
@export_range(0.1, 1.0, 0.05) var leader_speed_ratio: float = 0.6
## Leader: distance of a wander target (px, min / max).
@export var leader_wander_distance: Vector2 = Vector2(30.0, 120.0)
## Leader: pause between two wander moves (s, min / max).
@export var leader_pause_range: Vector2 = Vector2(1.5, 4.0)

var wander_target: Vector2
var wander_time: float = 0.0
var leader_pausing: bool = true
var leader_dest: Vector2
var flocking: FlockingProfile = null
var forces_timer: float = 0.0
var forces_timer_steps: float

## Walk animation starts above this speed and stops below the second one (hysteresis: no flicker)
const WALK_START_SPEED_SQUARED: float = 25.0 * 25.0
const WALK_STOP_SPEED_SQUARED: float = 12.0 * 12.0
var is_walking: bool = false
var applied_animation: String = ""

var game_paused: bool = false
var game_over: bool = false
var day_is_ended: bool = false


func _ready() -> void:
	if default_flocking == null:
		default_flocking = FlockingProfile.new()
	forces_timer_steps = randf_range(update_interval_range.x, update_interval_range.y)
	forces_timer = randf_range(0.0, forces_timer_steps)
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.game_is_over.connect(_on_game_over)
	SignalManager.day_time_end.connect(_on_day_end)
	SignalManager.enemy_stats_init.connect(_on_stats_init)


func enter() -> void:
	flocking = resolve_profile()
	enemy.facing_direction = Vector2.ZERO
	is_walking = false
	applied_animation = ""   # forces the animation to be applied on the next update
	# Leader starts with a pause: never walks toward an uninitialized target
	leader_pausing = true
	wander_time = randf_range(leader_pause_range.x, leader_pause_range.y)


func exit() -> void:
	# Other states orient the sprite from the velocity again
	enemy.facing_direction = Vector2.ZERO


func resolve_profile() -> FlockingProfile:
	if enemy.enemy != null and enemy.enemy.idle_flocking != null:
		return enemy.enemy.idle_flocking
	return default_flocking


func physics_update(delta: float) -> void:
	if game_paused:
		return
	if enemy.is_leader:
		leader_behavior(delta)
		update_idle_animation()
		return
	forces_timer -= delta
	if forces_timer > 0.0:
		return
	forces_timer = forces_timer_steps
	trouper_behavior()
	update_idle_animation()


## Walk to a target, then pause. A target that takes too long (wall) also ends in a pause.
func leader_behavior(delta: float) -> void:
	wander_time -= delta
	if leader_pausing:
		enemy.velocity = Vector2.ZERO
		if wander_time <= 0.0:
			leader_pausing = false
			pick_wander_target()
		return

	var to_target: Vector2 = wander_target - enemy.global_position
	if to_target.length_squared() <= 25.0 or wander_time <= 0.0:
		leader_pausing = true
		wander_time = randf_range(leader_pause_range.x, leader_pause_range.y)
		enemy.velocity = Vector2.ZERO
		return
	enemy.velocity = to_target.normalized() * enemy.speed.get_value() * leader_speed_ratio


func pick_wander_target() -> void:
	var angle: float = randf() * TAU
	var distance: float = randf_range(leader_wander_distance.x, leader_wander_distance.y)
	wander_target = enemy.global_position + Vector2(cos(angle), sin(angle)) * distance
	leader_dest = wander_target
	# Travel timeout: expected travel time + 1 s
	var leader_speed: float = maxf(enemy.speed.get_value() * leader_speed_ratio, 1.0)
	wander_time = distance / leader_speed + 1.0


func trouper_behavior() -> void:
	if flocking == null:
		flocking = resolve_profile()
	var base_speed: float = enemy.speed.get_value()
	# No leader (dead or none): settles with its neighbors
	if !is_instance_valid(enemy.leader):
		enemy.velocity = FlockingSteering.compute_velocity(enemy, Vector2.ZERO, base_speed * settle_speed_ratio, flocking)
		return

	var goal: Vector2 = Vector2.ZERO
	var speed: float = base_speed * settle_speed_ratio
	var to_leader: Vector2 = enemy.leader.global_position - enemy.global_position
	var distance: float = to_leader.length()
	# Leader walking: the whole pack walks with him and faces his heading
	var leader_velocity: Vector2 = enemy.leader.velocity
	if leader_velocity.length_squared() > 1.0 and base_speed > 0.0:
		goal = leader_velocity / base_speed
		speed = base_speed
		enemy.facing_direction = leader_velocity
	# Outside the pack: pulled back toward the leader (and faces him if he is standing still)
	if distance > pack_radius:
		goal += (to_leader / distance) * clampf((distance - pack_radius) / pack_radius, 0.3, 1.0)
		speed = base_speed
		if leader_velocity.length_squared() <= 1.0:
			enemy.facing_direction = to_leader
	# Leader paused: facing_direction is kept, the pack stays calmly oriented
	enemy.velocity = FlockingSteering.compute_velocity(enemy, goal, speed, flocking)


func _on_game_over(game_is_over: bool) -> void:
	game_over = game_is_over


func _on_game_paused(game_on_pause: bool) -> void:
	game_paused = game_on_pause


func _on_day_end(_day_end: bool) -> void:
	state_changed.emit(self, "chase")


func _on_stats_init(which: Enemy) -> void:
	if which == enemy:
		enter()


## "walk" while moving, "idle" while standing. Only calls the renderer when the animation changes.
func update_idle_animation() -> void:
	var speed_squared: float = enemy.velocity.length_squared()
	if is_walking and speed_squared < WALK_STOP_SPEED_SQUARED:
		is_walking = false
	elif !is_walking and speed_squared > WALK_START_SPEED_SQUARED:
		is_walking = true
	var desired: String = "walk" if is_walking else "idle"
	if desired != applied_animation and enemy.play_animation(desired):
		applied_animation = desired
