class_name  AmmoMG
extends Area2D

@export var bullet_data: WeaponData

var speed : float
var max_range : float
var damages : int
var damages_upgrade : int
var current_lvl : int
var max_lvl : int
var knockback_force : int = 250
var max_range_squared: float

var velocity : Vector2
var start_position : Vector2

@onready var parent_weapon: Node2D = $"/root/World/Car/Weapons/Minigun"
@onready var camera_2d: Camera2D = $/root/World/Car/Camera2D

var game_paused:= false

var is_active:= false

@export var wall_mask: int = 8
var ray_params: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.new()


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	max_lvl = bullet_data.max_level
	speed = bullet_data.speed.get_value()
	max_range = bullet_data.atk_range.get_value()
	max_range_squared = max_range * max_range
	damages = int(bullet_data.dmg.get_value())
	ray_params.collision_mask = wall_mask
	ray_params.collide_with_areas = false


func fire(from_position: Vector2, direction: Vector2, angle: float) -> void:
	global_position = from_position
	start_position = from_position
	velocity = direction.normalized() * bullet_data.speed.get_value()
	self.show()
	is_active = true
	set_process(true)
	set_deferred("monitoring", true)
	#set_deferred("monitorable", true)
	global_rotation = angle
	camera_2d.screen_shake(5,0.5)



func _process(delta: float) -> void:
	if game_paused:
		return
	if !bullet_data.weapon_is_active:
		desactivate()
	var previous: Vector2 = global_position
	global_position += velocity * delta

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


func activate() -> void :
	if !is_active:
		is_active = true
		visible = true
		set_process(true)

func _on_body_entered(body: Node2D) -> void:
	if is_active:
		if body.is_in_group("walls"):
			desactivate()


func _on_area_entered(area: Area2D) -> void:
	if is_active:
		if "get_damages" in area and area.is_in_group("ennemies") and is_active:
	# reminder : func get_damages(damages: int, hit_direction: Vector2 = Vector2.ZERO, knockback_force: float = 0.0) -> void:
			area.get_damages(bullet_data.dmg.get_value(), velocity, knockback_force)
			bullet_data.total_damages_dealt += int(bullet_data.dmg.get_value())
			desactivate()
		if area.is_in_group("walls"):
			desactivate()
