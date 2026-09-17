extends Node2D

signal grenade_landed(world_position : Vector2)

@export_category("GENERAL")
@export var grenade_data : WeaponData
@export var explosion_scene : PackedScene


@export_group("THROW")
@export var max_distance : float = 150.0
@export var max_distance_random : float = 25.0
@export var duration : float = 0.7 #in sec
@export var duration_random : float = 0.08

@export_group("LANDING")
@export var landing_rad_clearance : float = 14.0 #radius clear of buildings
@export var landing_attempts : int = 8

@export_group("FLIGHT FX")
@export var spin_turns : float = 2.0
@export var arc_peak_scale : float = 1.9
## Extra upward sprite offset at the top of the arc, in pixels
@export var arc_peak_lift : float = 18.0

@onready var sprite : Sprite2D = $Icon

var start_pos : Vector2 = Vector2.ZERO
var target_pos : Vector2 = Vector2.ZERO
var sprite_base_scale : Vector2 = Vector2.ONE
var spin_amount : float = 0.0
var flight_duration : float = 0.0
var can_launch : bool = false
var game_paused : bool = false

var damages : int
var current_lvl : int
var max_lvl : int
var expl_limitor : int = 0

var targets: Array[Node2D]

@onready var flow_field: FlowFieldManager = $/root/World/FlowFieldManager
@onready var explosion_sfx: AudioStreamPlayer2D = $ExplosionSFX
@onready var explosion_shape: CollisionShape2D = $ExplosionArea/ExplosionShape
@onready var camera_2d: Camera2D = $/root/World/Car/Camera2D



func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	sprite_base_scale = sprite.scale

	max_lvl = grenade_data.max_level
	explosion_sfx.stream = grenade_data.weapon_sfx
	damages = int(grenade_data.dmg.get_value())

	if flow_field == null:
		push_warning("Grenade: no FlowFieldManager in group 'flow_field', landing spots are not checked")

	# The launcher may have called launch_grenade() before add_child()
	if can_launch:
		can_launch = false
		start_flight()


## Called by the launcher. from_pos is the car global_position.
func launch_grenade(from_pos : Vector2) -> void:
	start_pos = from_pos
	global_position = from_pos

	spin_amount = spin_turns * TAU * (1.0 if randf() < 0.5 else -1.0)
	flight_duration = maxf(0.05, duration + randf_range(-duration_random, duration_random))

	# The target needs the physics world: defer until we are in the tree
	if not is_inside_tree():
		can_launch = true
		return
	start_flight()


func start_flight() -> void:
	target_pos = pick_landing_position(start_pos)
	var tween : Tween = create_tween()
	tween.tween_method(apply_flight, 0.0, 1.0, flight_duration)
	tween.tween_callback(on_grenade_landed)


func pick_landing_position(from_pos : Vector2) -> Vector2:
	var base_distance : float = maxf(8.0, max_distance + randf_range(-max_distance_random, max_distance_random))

	# No grid yet : throw blind
	if flow_field == null or not flow_field.field_ready:
		var blind_angle : float = randf() * TAU
		return from_pos + Vector2(cos(blind_angle), sin(blind_angle)) * base_distance

	for attempt : int in landing_attempts:
		var angle : float = randf() * TAU
		var distance : float = maxf(landing_rad_clearance, base_distance * (1.0 - 0.1 * float(attempt)))
		var candidate : Vector2 = from_pos + Vector2(cos(angle), sin(angle)) * distance
		if is_landing_clear(candidate):
			return candidate

	# Built up all around: drop it at the launcher's feet, a drivable cell by
	# definition.
	return from_pos


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


# sin(ratio * PI) gives 0 -> 1 -> 0: the perceived height of the grenade above the ground.
func apply_flight(ratio : float) -> void:
	global_position = start_pos.lerp(target_pos, ratio)
	var height : float = sin(ratio * PI)
	sprite.rotation = spin_amount * ratio
	sprite.scale = sprite_base_scale * (1.0 + (arc_peak_scale - 1.0) * height)
	sprite.position.y = -arc_peak_lift * height


func on_grenade_landed() -> void:
	sprite.rotation = 0.0
	sprite.scale = sprite_base_scale
	sprite.position = Vector2.ZERO
	grenade_landed.emit(global_position)
	self.hide()
	explosion()
	
func explosion()-> void:
	if expl_limitor >= 1:
		return
	expl_limitor = 1
	
	var new_explosion : Node2D = explosion_scene.instantiate()
	new_explosion.global_position = self.global_position
	get_node("/root/World/VFX/Explosions").add_child(new_explosion)
	
	explosion_sfx.play()
	camera_2d.screen_shake(8,0.5)
	
	for i in range(targets.size() -1, -1, -1):

		if is_instance_valid(targets[i]):
			if targets[i].is_in_group("ennemies") and "get_damages" in targets[i]:
				targets[i].get_damages(grenade_data.dmg.get_value())
				grenade_data.total_damages_dealt += int(grenade_data.dmg.get_value())

			elif targets[i].is_in_group("explosives") and "chain_explosion" in targets[i]:
				targets[i].chain_explosion(self)


func chain_explosion(from_mine : Node2D) -> void:
	for i in range(targets.size()-1,-1,-1):
		if targets[i] == from_mine:
			targets.remove_at(i)
			break
	await get_tree().create_timer(0.2).timeout
	explosion()


func _on_explosion_animation_finished() -> void:
	targets.clear()
	expl_limitor = 0
	self.queue_free()


func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause


func _on_explosion_area_entered(area: Area2D) -> void:
	if area.is_in_group("ennemies"):
		targets.append(area)


func _on_explosion_area_exited(area: Area2D) -> void:
	if area.is_in_group("ennemies") and targets.has(area):
		for i in range(targets.size()-1,-1,-1):
			if is_instance_valid(targets[i]):
				if targets[i] == area : 
					targets.remove_at(i)


func _on_explosion_area_shape_entered(_area_rid: RID, area: Area2D, _area_shape_index: int, _local_shape_index: int) -> void:
	if area.is_in_group("explosives"):
		targets.append(area.get_parent())


func _on_explosion_sfx_finished() -> void:
	targets.clear()
	expl_limitor = 0
	self.queue_free()
