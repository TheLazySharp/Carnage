extends State
class_name EnemyChase

@onready var enemy: Enemy = $"../.."
@onready var flow_field: FlowFieldManager = $"/root/World/FlowFieldManager"

## Used when the EnemyData has no chase_flocking profile.
@export var default_flocking: FlockingProfile = null
## Steering refresh interval (s, min / max). Lower = tighter pack, higher = cheaper.
@export var update_interval_range: Vector2 = Vector2(0.12, 0.18)

var chase_speed_boost: float = 1.6
var game_paused: bool = false
var game_over: bool = false
var flocking: FlockingProfile = null
var animation_applied: bool = false

# STAGGER: direction is not recomputed every SM tick
var update_timer: float = 0.0
var update_interval: float


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.game_is_over.connect(_on_game_over)
	if default_flocking == null:
		default_flocking = FlockingProfile.new()
	update_interval = randf_range(update_interval_range.x, update_interval_range.y)
	update_timer = randf_range(0.0, update_interval)


func enter() -> void:
	if game_over:
		state_changed.emit(self, "idle")
		return
	flocking = resolve_profile()
	animation_applied = false


func exit() -> void:
	pass


func resolve_profile() -> FlockingProfile:
	if enemy.enemy != null and enemy.enemy.chase_flocking != null:
		return enemy.enemy.chase_flocking
	return default_flocking


func physics_update(delta: float) -> void:
	if game_paused:
		return
	update_timer -= delta
	if update_timer > 0.0:
		return
	update_timer = update_interval
	if flocking == null:
		flocking = resolve_profile()

	var goal: Vector2 = flow_field.get_flow_direction_smooth(enemy.global_position)
	enemy.velocity = FlockingSteering.compute_velocity(enemy, goal, enemy.speed.get_value() * chase_speed_boost, flocking)
	if !animation_applied:
		animation_applied = enemy.play_animation("run")

func _on_game_over(game_is_over: bool) -> void:
	game_over = game_is_over
	if game_is_over:
		state_changed.emit(self, "idle")


func _on_game_paused(game_on_pause: bool) -> void:
	game_paused = game_on_pause
