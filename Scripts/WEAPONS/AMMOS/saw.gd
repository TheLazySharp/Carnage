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

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	damages = saw_data.dmg.get_value()
	speed = saw_data.speed.get_value()
	speed_rotation = saw_data.speed_rotation.get_value()

func _process(delta: float) -> void:
	if game_paused:
		return
	icon.rotation += delta * speed_rotation
	global_position += velocity * delta
	
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
	global_position = from_position
	start_position = from_position
	velocity = direction.normalized() * speed
	damage_multiplier = p_damage_multiplier
	show()
	is_active = true
	set_process(true)

func desactivate() -> void: 
	self.queue_free()

func _on_screen_exited() -> void:
	desactivate()

func _on_cut_body_entered(body: Node2D) -> void:
	if is_active and body.is_in_group("walls"):
		desactivate()
