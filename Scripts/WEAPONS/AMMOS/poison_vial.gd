extends Node2D

signal vial_landed(world_position : Vector2)

@export_category("GENERAL")
@export var vial_data : WeaponData
@export var explosion_scene : PackedScene
@export var puddle_scene : PackedScene

@export_group("THROW")
@export var max_distance : float = 150.0
@export var max_distance_random : float = 25.0
@export var duration : float = 0.7 #in sec
@export var duration_random : float = 0.08

@export_group("LANDING")
@export var landing_rad_clearance : float = 14.0 #radius clear of buildings
@export var landing_attempts : int = 8
## Random deviation around a directed throw (degrees), widened on each blocked landing attempt
@export var direction_jitter_degrees : float = 10.0


@export_group("FLIGHT FX")
@export var arc_peak_scale : float = 1.9
@export var arc_peak_lift : float = 18.0

var start_pos : Vector2 = Vector2.ZERO
var target_pos : Vector2 = Vector2.ZERO
var sprite_base_scale : Vector2 = Vector2.ONE
var sprite_base_y : float = 0.0
var flight_tween : Tween = null
var flight_duration : float = 0.0
var can_launch : bool = false
var game_paused : bool = false

var damages : int
var current_lvl : int
var max_lvl : int
var expl_limitor : int = 0
var throw_angle : float = NAN        # set by the launcher for a directed throw, NAN = random direction
var damage_multiplier : float = 1.0  # set by the launcher (combo)

var targets: Array[Node2D]

@onready var flow_field: FlowFieldManager = $/root/World/FlowFieldManager
@onready var explosion_sfx: AudioStreamPlayer = $ExplosionSFX
@onready var explosion_shape: CollisionShape2D = $ExplosionArea/ExplosionShape
@onready var camera_2d: Camera2D = $/root/World/Car/Camera2D
@onready var poison_animation: AnimationPlayer = $PoisonAnimation
@onready var poison_vial_sprite: AnimatedSprite2D = $PoisonVial
@onready var poison_particles: GPUParticles2D = $PoisonVial/Pivot/PoisonParticles




func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	sprite_base_scale = poison_vial_sprite.scale
	sprite_base_y = poison_vial_sprite.position.y
	max_lvl = vial_data.max_level
	explosion_sfx.stream = vial_data.weapon_sfx
	damages = int(vial_data.dmg.get_value())

	if flow_field == null:
		push_warning("poison vial: no FlowFieldManager in group 'flow_field', landing spots are not checked")

	# The launcher may have called launch_vial() before add_child()
	if can_launch:
		can_launch = false
		start_flight()


## Called by the launcher. from_pos is the car global_position.
## p_throw_angle: world direction of a directed throw (NAN = random direction)
func launch_vial(from_pos : Vector2, p_throw_angle : float = NAN, p_damage_multiplier : float = 1.0) -> void:
	start_pos = from_pos
	global_position = from_pos
	throw_angle = p_throw_angle
	damage_multiplier = p_damage_multiplier

	flight_duration = maxf(0.05, duration + randf_range(-duration_random, duration_random))

	# The target needs the physics world: defer until we are in the tree
	if not is_inside_tree():
		can_launch = true
		return
	start_flight()


func start_flight() -> void:
	target_pos = pick_landing_position(start_pos)
	play_vfx(true)
	flight_tween = create_tween()
	flight_tween.tween_method(apply_flight, 0.0, 1.0, flight_duration)
	flight_tween.tween_callback(on_vial_landed)
	# Thrown during a pause (deferred launch): wait for the game to resume
	if game_paused:
		flight_tween.pause()
		pause_vfx(true)


func pick_landing_position(from_pos : Vector2) -> Vector2:
	var base_distance : float = maxf(8.0, max_distance + randf_range(-max_distance_random, max_distance_random))

	# No grid yet : throw blind
	if flow_field == null or not flow_field.field_ready:
		var blind_angle : float = pick_throw_angle(0)
		return from_pos + Vector2(cos(blind_angle), sin(blind_angle)) * base_distance

	for attempt : int in landing_attempts:
		var angle : float = pick_throw_angle(attempt)
		var distance : float = maxf(landing_rad_clearance, base_distance * (1.0 - 0.1 * float(attempt)))
		var candidate : Vector2 = from_pos + Vector2(cos(angle), sin(angle)) * distance
		if is_landing_clear(candidate):
			return candidate

	# Built up all around: drop it at the launcher's feet, a drivable cell by
	# definition.
	return from_pos


func pick_throw_angle(attempt : int) -> float:
	if is_nan(throw_angle):
		return randf() * TAU
	# Directed throw: small jitter, widening with each blocked attempt
	return throw_angle + deg_to_rad(randf_range(-direction_jitter_degrees, direction_jitter_degrees)) * float(1 + attempt)


## Center cell plus four cardinal probes at landing_rad_clearance: five array reads,
## zero allocation. is_blocked_world() already returns true outside the map, so
## the map border needs no separate test.
func is_landing_clear(world_pos : Vector2) -> bool:
	if flow_field.is_blocked_world(world_pos):
		return false
	if flow_field.is_blocked_world(world_pos + Vector2(landing_rad_clearance, 0.0)):
		return false
	if flow_field.is_blocked_world(world_pos - Vector2(landing_rad_clearance, 0.0)):
		return false
	if flow_field.is_blocked_world(world_pos + Vector2(0.0, landing_rad_clearance)):
		return false
	if flow_field.is_blocked_world(world_pos - Vector2(0.0, landing_rad_clearance)):
		return false
	return true

func apply_flight(ratio : float) -> void:
	global_position = start_pos.lerp(target_pos, ratio)
	var height : float = sin(ratio * PI)
	# The arc is drawn on the sprite: the vial itself follows the ground path (landing / explosion position)
	poison_vial_sprite.scale = sprite_base_scale * (1.0 + (arc_peak_scale - 1.0) * height)
	poison_vial_sprite.position.y = sprite_base_y - arc_peak_lift * height


func on_vial_landed() -> void:
	play_vfx(false)
	vial_landed.emit(global_position)
	explosion()
	queue_free()


func explosion()-> void:
	if expl_limitor >= 1:
		return
	expl_limitor = 1
	
	var new_explosion : Node2D = explosion_scene.instantiate()
	new_explosion.global_position = self.global_position
	get_node("/root/World/VFX/Explosions").add_child(new_explosion)
	
	_play_detached_sfx()
	camera_2d.screen_shake(8,0.5)
	_spawn_puddle()
	
	var dealt : int = roundi(vial_data.dmg.get_value() * damage_multiplier)
	for i in range(targets.size() -1, -1, -1):
		var target : Node2D = targets[i]
		if !is_instance_valid(target) or !target.is_in_group("ennemies"):
			continue
		if "get_damages" in target:
			target.get_damages(dealt, Vector2.ZERO, 0.0, vial_data.death_type)
			vial_data.total_damages_dealt += dealt
		if vial_data.status != EnemyManager.Status.NONE and "apply_status" in target:
			target.apply_status(vial_data.status, vial_data.status_duration, vial_data.status_power)

## The sound outlives the vial (freed on landing): moved to the world, freed once played
func _play_detached_sfx() -> void:
	explosion_sfx.reparent(get_node("/root/World/VFX/Explosions"))
	explosion_sfx.finished.connect(explosion_sfx.queue_free)
	explosion_sfx.play()

## Poison puddle where the vial broke (scene not made yet: nothing while null)
func _spawn_puddle() -> void:
	if puddle_scene == null:
		return
	var puddle : Node2D = puddle_scene.instantiate()
	get_node("/root/World/VFX/Explosions").add_child(puddle)
	puddle.global_position = global_position


func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
	if flight_tween == null or !flight_tween.is_valid():
		return
	if game_on_pause:
		flight_tween.pause()
		pause_vfx(true)
	else:
		flight_tween.play()
		pause_vfx(false)


func _on_explosion_area_entered(area: Area2D) -> void:
	if area.is_in_group("ennemies"):
		targets.append(area)


func _on_explosion_area_exited(area: Area2D) -> void:
	if area.is_in_group("ennemies") and targets.has(area):
		for i in range(targets.size()-1,-1,-1):
			if is_instance_valid(targets[i]):
				if targets[i] == area : 
					targets.remove_at(i)



func play_vfx(start : bool) -> void :
	if start:
		poison_animation.play("poison_vial_particles")
		poison_vial_sprite.play("throw_a")
		poison_particles.emitting = true
	else : 
		poison_animation.stop()
		poison_vial_sprite.stop()
		poison_particles.emitting = false

func pause_vfx(pause : bool) -> void :
	if pause:
		poison_animation.pause()
		poison_vial_sprite.pause()
		poison_particles.speed_scale = 0.0
	else : 
		poison_animation.play()
		poison_vial_sprite.play()
		poison_particles.speed_scale = 1.0
		
