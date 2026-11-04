class_name  AmmoREV
extends Area2D

@export var bullet_data: WeaponData

@export_group("TRACER")
@export var tracers: Array[Line2D] = []
## the tracer covers the distance flown in that time (speed x duration)
@export var tracer_duration: float = 0.1
##  points snapped to this grid (pixel art)
@export var tracer_pixel_size: int = 1

var speed : float
var max_range : float
var damages : int
var damages_upgrade : int
var current_lvl : int
var max_lvl : int
var knockback_force : int = 150
var max_range_squared: float

var velocity : Vector2
var start_position : Vector2

@onready var parent_weapon: Node2D = $/root/World/Car/Weapons/Revolver
@onready var camera_2d: Camera2D = $/root/World/Car/Camera2D
@export var wall_mask: int = 8
var ray_params: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.new()
var damage_multiplier: float = 1.0  # set per shot (combo)
var game_paused:= false

var is_active:= false

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	max_lvl = bullet_data.max_level
	speed = bullet_data.speed.get_value()
	max_range = bullet_data.atk_range.get_value()
	max_range_squared = max_range * max_range
	damages = int(bullet_data.dmg.get_value())
	ray_params.collision_mask = wall_mask
	ray_params.collide_with_areas = false
	if not is_active:
		set_process(false)
	for tracer: Line2D in tracers:
		tracer.clear_points()
		tracer.add_point(Vector2.ZERO)
		tracer.add_point(Vector2.ZERO)

func fire(from_position: Vector2, direction: Vector2, angle: float, p_damage_multiplier: float = 1.0) -> void:
	global_position = from_position
	start_position = from_position
	velocity = direction.normalized() * bullet_data.speed.get_value()
	damage_multiplier = p_damage_multiplier
	self.show()
	is_active = true
	set_process(true)
	set_deferred("monitoring", true)
	global_rotation = angle
	_update_tracers()
	camera_2d.screen_shake(2,0.3)


func _process(delta: float) -> void:
	if game_paused:
		return
	if !bullet_data.weapon_is_active:
		desactivate()
	var previous: Vector2 = global_position
	global_position += velocity * delta
	_update_tracers()

	ray_params.from = previous
	ray_params.to = global_position
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray_params)
	if not hit.is_empty():
		global_position = hit["position"]  # exact impact point for the VFX
		desactivate()
		return

	if global_position.distance_squared_to(start_position) > max_range_squared:
		desactivate()

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause


func desactivate()-> void:
	if is_active:
		hide()
		is_active = false
		set_process(false)
		set_deferred("monitoring", false)
		#set_deferred("monitorable", false)
		global_position = Vector2(-10,-10)
		if parent_weapon: parent_weapon.add_bullet_to_pool(self)



func activate()->void:
	if !is_active:
		is_active = true
		visible = true
		set_process(true)

func _on_area_entered(area: Area2D) -> void:
	if is_active:
		if "get_damages" in area and area.is_in_group("ennemies") and is_active:
	# reminder : func get_damages(damages: int, hit_direction: Vector2 = Vector2.ZERO, knockback_force: float = 0.0, death_type: EnemyManager.Death_Types = DEFAULT) -> void:
			var dealt: int = roundi(bullet_data.dmg.get_value() * damage_multiplier)
			area.get_damages(dealt, velocity, knockback_force, bullet_data.death_type)
			bullet_data.total_damages_dealt += dealt
			desactivate()
		elif area.is_in_group("walls"):
			desactivate()

func _on_body_entered(body: Node2D) -> void:
	if is_active:
		if body.is_in_group("walls"):
			desactivate()


## Head on the bullet, tail at the distance flown in tracer_duration (shorter while it leaves the muzzle).
## to_local: right whatever the bullet / sprite rotation
func _update_tracers() -> void:
	if tracers.is_empty():
		return
	var full_length: float = velocity.length() * tracer_duration
	var length: float = minf(global_position.distance_to(start_position), full_length)
	var snap: Vector2 = Vector2(tracer_pixel_size, tracer_pixel_size)
	var head: Vector2 = global_position.snapped(snap)
	var tail: Vector2 = (global_position - velocity.normalized() * length).snapped(snap)
	for tracer: Line2D in tracers:
		# Point 0 = head: the Gradient reads like the artist's (0 = fresh, 1 = expired)
		tracer.set_point_position(0, tracer.to_local(head))
		tracer.set_point_position(1, tracer.to_local(tail))
