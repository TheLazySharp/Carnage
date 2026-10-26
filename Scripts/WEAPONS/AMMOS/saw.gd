extends Node2D

@export_category("GENERAL")
@export var saw_data : WeaponData

@onready var icon: Sprite2D = $Icon

var damages : float
var speed : float
var speed_rotation : float
var knockback_force : float = 200
var game_paused : bool = false

var velocity : Vector2
var start_position : Vector2
var damage_multiplier: float = 1.0
var is_active : bool = false
var launcher : Node2D = null  # owner pool, set at creation
@export var cut_area : Area2D
@export var wall_mask : int = 8
## Blade radius for the wall test: the saw stops when its edge touches the wall, not its center
@export var wall_hit_radius : float = 16.0
var ray_params : PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.new()
var move_direction : Vector2 = Vector2.ZERO


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	damages = saw_data.dmg.get_value()
	speed = saw_data.speed.get_value()
	speed_rotation = saw_data.speed_rotation.get_value()
	ray_params.collision_mask = wall_mask
	ray_params.collide_with_areas = false
	# A saw thrown while the car hugs a wall starts inside it: it must break right away
	ray_params.hit_from_inside = true
	if !is_active:
		hide()
		set_process(false)
		_set_cut_enabled(false)

func _process(delta: float) -> void:
	if game_paused:
		return
	icon.rotation += delta * speed_rotation
	var previous : Vector2 = global_position
	global_position += velocity * delta
	# Same wall test as the minigun bullets: a ray over this frame's move, reaching the blade edge
	ray_params.from = previous
	ray_params.to = global_position + move_direction * wall_hit_radius
	var hit : Dictionary = get_world_2d().direct_space_state.intersect_ray(ray_params)
	if !hit.is_empty():
		_on_wall_hit(hit["position"])
	
func _on_cut_area_entered(area: Area2D) -> void:
	if !is_active:
		return
	if area.is_in_group("ennemies") and "get_damages" in area:
		# reminder : func get_damages(damages: int, hit_direction: Vector2 = Vector2.ZERO, knockback_force: float = 0.0, death_type: EnemyManager.Death_Types = DEFAULT) -> void:
		var dealt: int = roundi(damages * damage_multiplier)
		area.get_damages(dealt, velocity, knockback_force, saw_data.death_type)
		saw_data.total_damages_dealt += dealt

func _on_game_paused(games_is_paused : bool) -> void : 
	game_paused = games_is_paused

func throw(from_position: Vector2, direction: Vector2, p_damage_multiplier: float = 1.0) -> void:
	# Stats read on every throw: a pooled saw follows the modifiers added during the raid
	damages = saw_data.dmg.get_value()
	speed = saw_data.speed.get_value()
	speed_rotation = saw_data.speed_rotation.get_value()
	global_position = from_position
	start_position = from_position
	move_direction = direction.normalized()
	velocity = move_direction * speed
	damage_multiplier = p_damage_multiplier
	is_active = true
	show()
	set_process(true)
	_set_cut_enabled(true)

## Back to the launcher's pool (freed only if it has no launcher)
func desactivate() -> void:
	if !is_active:
		return  # already pooled: the screen exit after the move off-screen lands here
	is_active = false
	hide()
	set_process(false)
	_set_cut_enabled(false)
	global_position = Vector2(-1000.0, -1000.0)
	if launcher != null:
		launcher.return_saw(self)
	else:
		queue_free()

func _set_cut_enabled(enabled: bool) -> void:
	if cut_area != null:
		cut_area.set_deferred("monitoring", enabled)

func _on_screen_exited() -> void:
	desactivate()

## The blade bites into the wall: placed at the contact point, then removed (wall VFX / SFX go here)
func _on_wall_hit(hit_position : Vector2) -> void:
	global_position = hit_position - move_direction * wall_hit_radius
	desactivate()
