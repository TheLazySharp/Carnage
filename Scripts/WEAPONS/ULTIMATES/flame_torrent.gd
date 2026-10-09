extends Area2D
## Ultimate "flame torrent": the loop area burns for a few seconds.
## Scene: Area2D (enemy mask) > CollisionPolygon2D + Polygon2D (placeholder visual)

@export var duration: float = 2.5
@export var tick_interval: float = 0.25
@export var damage_per_tick: int = 20
@export var death_type: EnemyManager.DEATH_TYPES = EnemyManager.DEATH_TYPES.DEFAULT
@export var fade_time: float = 0.4

@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D
@onready var visual: Polygon2D = $Polygon2D

var time_left: float = 0.0
var tick_timer: float = 0.0
var damage: int = 0
var game_paused: bool = false


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	set_physics_process(false)


func trigger(polygon: PackedVector2Array, damage_multiplier: float) -> void:
	collision_polygon.polygon = polygon
	visual.polygon = polygon
	damage = roundi(damage_per_tick * damage_multiplier)
	time_left = duration
	# First burn after one interval: the overlaps need a physics frame to be known
	tick_timer = tick_interval
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if game_paused:
		return
	time_left -= delta
	tick_timer -= delta
	if tick_timer <= 0.0:
		tick_timer += tick_interval
		_burn()
	if time_left <= 0.0:
		set_physics_process(false)
		_finish()


func _burn() -> void:
	for area: Area2D in get_overlapping_areas():
		if area.is_in_group("ennemies") and "get_damages" in area:
			area.get_damages(damage, Vector2.ZERO, 0.0, death_type)


func _finish() -> void:
	set_deferred("monitoring", false)
	var tween: Tween = create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, fade_time)
	tween.tween_callback(queue_free)


func _on_game_paused(game_on_pause: bool) -> void:
	game_paused = game_on_pause
