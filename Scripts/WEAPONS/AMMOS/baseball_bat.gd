extends Node2D
class_name BaseballBat


@export_group("PHYSICS")
@export var bat_data : WeaponData
@export var swing_animations : Array[StringName] = [&"swing_1", &"swing_2", &"swing_3", &"swing_4"]
## Stroke of each animation in car local degrees (0 = front, -90 = left, 90 = right), drawn version (left side, by the front)
@export var swing_start_degrees : PackedFloat32Array = [-150.0, -150.0, -150.0, -150.0]
@export var swing_end_degrees : PackedFloat32Array = [-45.0, 30.0, 150.0, 210.0]
## Share of each animation during which the stroke deals damage, from the first frame (0 = whole stroke at once)
@export var sweep_time_ratios : PackedFloat32Array = [0.25, 0.25, 0.25, 0.25]
@export var swing_radius : float = 65.0                 # bat reach from the car sprite center (px)
@export var sweep_tolerance_degrees : float = 15.0      # extra angle behind the bat: fast enemies are not skipped
@export var knockback_force : float = 1500.0
@export var kill_knockback_force : float = 300.0
@export_flags_2d_physics var enemy_mask : int = 0

@export_group("JUICE")
@export var punch_sfx_min_interval : float = 0.07  # real seconds
@export var impact_count : int = 4


@onready var punch_sfx: AudioStreamPlayer = $PunchSFX
@onready var whoosh_sfx : AudioStreamPlayer = $WhooshSFX
@onready var sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var player : CharacterBody2D = $/root/World/Car
@onready var impact_animation: AnimatedSprite2D = $ImpactAnimation

var game_paused : bool = false
var swinging : bool = false
var swing_damage : int = 0
var swing_duration : float = 0.0
var swing_elapsed : float = 0.0
var sweep_start : float = 0.0      # car local degrees
var sweep_dir : float = 1.0        # +1: angle increasing, -1: decreasing (flipped strokes)
var sweep_total : float = 0.0      # degrees covered by the stroke
var swept_so_far : float = 0.0
var sweep_time : float = 0.0       # seconds to sweep the whole stroke
var sweep_done : bool = false
var hit_enemies : Array[Enemy] = []
var query : PhysicsShapeQueryParameters2D
var last_punch_time : float = -1000.0
var impacts : Array[AnimatedSprite2D] = []
var impact_index : int = 0

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	sprite.hide()
	sprite.animation_finished.connect(sprite.hide)
	var reach : CircleShape2D = CircleShape2D.new()
	reach.radius = swing_radius
	query = PhysicsShapeQueryParameters2D.new()
	query.shape = reach
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = enemy_mask

	impact_animation.top_level = true
	impact_animation.hide()
	impacts.append(impact_animation)
	for i : int in maxi(impact_count, 1) - 1:
		var copy : AnimatedSprite2D = impact_animation.duplicate() as AnimatedSprite2D
		add_child(copy)
		impacts.append(copy)
	for impact : AnimatedSprite2D in impacts:
		impact.animation_finished.connect(impact.hide)

## animation_index: 0..3. right_side / rear: mirrored strokes. A new swing replaces the one in progress
func swing(animation_index : int, right_side : bool, rear : bool, damage : int) -> void:
	var start : float = swing_start_degrees[animation_index]
	var end : float = swing_end_degrees[animation_index]
	if right_side:
		start = -start
		end = -end
	if rear:
		start = 180.0 - start
		end = 180.0 - end
	sweep_start = start
	sweep_dir = signf(end - start)
	sweep_total = absf(end - start)
	swept_so_far = 0.0
	swing_damage = damage
	hit_enemies.clear()

	var animation_name : StringName = swing_animations[animation_index]
	var frames : SpriteFrames = sprite.sprite_frames
	var relative_length : float = 0.0
	for frame : int in frames.get_frame_count(animation_name):
		relative_length += frames.get_frame_duration(animation_name, frame)
	swing_duration = maxf(relative_length / maxf(frames.get_animation_speed(animation_name), 0.001), 0.01)
	swing_elapsed = 0.0
	sweep_time = swing_duration * sweep_time_ratios[animation_index]
	sweep_done = false

	_follow_car()
	sprite.flip_h = right_side
	sprite.flip_v = rear
	sprite.show()
	sprite.stop()
	sprite.play(animation_name)
	whoosh_sfx.play()
	swinging = true
	# First hit on the first frame: the drawing starts with the stroke
	_update_sweep()


func _process(delta : float) -> void:
	if !swinging or game_paused:
		return
	_follow_car()
	swing_elapsed += delta
	_update_sweep()
	if swing_elapsed >= swing_duration:
		swinging = false


## Damage along the stroke, swept over sweep_time from the first frame (0 = whole stroke at once).
## The trail that fades after the stroke deals no damage
func _update_sweep() -> void:
	if sweep_done:
		return
	var progress : float = sweep_total
	if sweep_time > 0.0:
		progress = sweep_total * minf(swing_elapsed / sweep_time, 1.0)
	_hit_swept(swept_so_far - sweep_tolerance_degrees, progress)
	swept_so_far = progress
	sweep_done = progress >= sweep_total


## On the car sprite center, drawn facing up: +90 degrees to match the car front
func _follow_car() -> void:
	global_position = player.car_sprite.global_position
	global_rotation = player.global_rotation + PI * 0.5


## Enemies in reach whose angle along the stroke is between from_degrees and to_degrees, once per swing
func _hit_swept(from_degrees : float, to_degrees : float) -> void:
	var center : Vector2 = player.car_sprite.global_position
	var car_rotation : float = player.global_rotation
	query.transform = Transform2D(0.0, center)
	var hit_count : int = 0
	for result : Dictionary in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var enemy : Enemy = _get_enemy(result["collider"])
		if enemy == null or enemy.is_dead or hit_enemies.has(enemy):
			continue
		var offset : Vector2 = enemy.global_position - center
		var local_degrees : float = rad_to_deg(offset.angle() - car_rotation)
		var along : float = fposmod((local_degrees - sweep_start) * sweep_dir, 360.0)
		if along < from_degrees or along > to_degrees:
			continue
		hit_enemies.append(enemy)
		hit_count += 1
		# Outward, carried along the stroke
		var outward : Vector2 = offset.normalized()
		var push : Vector2 = outward + outward.rotated(PI * 0.5 * sweep_dir) * 0.5
		# Defensive weapon: survivors pushed far to clear the horde, corpses only a little
		var force : float = kill_knockback_force if enemy.current_life <= swing_damage else knockback_force
		enemy.get_damages(swing_damage, push, force, bat_data.death_type)
		bat_data.total_damages_dealt += swing_damage
		if bat_data.status != EnemyManager.Status.NONE:
			enemy.apply_status(bat_data.status, bat_data.status_duration, bat_data.status_power)
		_play_impact(enemy.global_position)
	if hit_count > 0:
		_play_punch()

## Rate limited in real time: the hit stop slows the game clock, not the sound
func _play_punch() -> void:
	var now : float = Time.get_ticks_msec() / 1000.0
	if now - last_punch_time < punch_sfx_min_interval:
		return
	last_punch_time = now
	punch_sfx.play()


## The oldest star of the pool, restarted on the hit enemy
func _play_impact(hit_position : Vector2) -> void:
	var impact : AnimatedSprite2D = impacts[impact_index]
	impact_index = (impact_index + 1) % impacts.size()
	impact.global_position = hit_position
	impact.show()
	impact.stop()
	impact.play()

## The query returns an enemy root area or one of its child areas: both resolve to the enemy
func _get_enemy(collider : Object) -> Enemy:
	var found : Enemy = collider as Enemy
	if found == null:
		var node : Node = collider as Node
		if node != null:
			found = node.get_parent() as Enemy
	return found


func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
	if game_paused:
		sprite.pause()
	elif swinging:
		sprite.play()
