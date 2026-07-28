extends Node2D
class_name Building

var building_data : BuildingData
const CELL_SIZE : float = 32.0
const DOLLAR_EDGE_PAD : float = 16.0 
@export var unlock_timer : float = 5
var player_in_area : bool = false
var footprint : Vector2i = Vector2i(1, 1)
@export var segments : int = 48
var margin : float

@onready var line : Line2D = $Line2D
@onready var unlockable_shape: CollisionShape2D = $BuildingArea/UnlockableShape
@onready var building_area: Area2D = $BuildingArea
@onready var unlock_bar: ProgressBar = $UnlockBar
@onready var spawn_center: Marker2D = $SpawnCenter

func _ready() -> void:
	footprint = (building_data.footprint_32)
	margin = building_data.circle_margin 
	draw_circle_around_footprint()
	unlock_bar.max_value = unlock_timer
	unlock_bar.value = unlock_timer

func _process(delta: float) -> void:
	if !player_in_area:
		return
	unlock_timer -= delta
	unlock_bar.value = unlock_timer
	if unlock_timer <= 0:
		unlock_timer = 0
		_on_unlock_timer_timeout()


func draw_circle_around_footprint() -> void:
	var size_px : Vector2 = Vector2(footprint) * CELL_SIZE

	var center : Vector2 = size_px * 0.5 #if anchor on top left corner
	building_area.position = center
	spawn_center.position = center

	var radius : float = size_px.length() * 0.5 + margin
	unlockable_shape.shape.radius = radius

	line.clear_points()
	for i in range(segments + 1):
		var angle : float = TAU * float(i) / float(segments)
		line.add_point(center + Vector2(cos(angle), sin(angle)) * radius)
	line.closed = true
	line.width = 2
	line.default_color = FontManager.dark_yellow

func clear_circle()-> void: 
	line.clear_points()


func _on_building_area_body_entered(body: Node2D) -> void:
	if !body.is_in_group("player"):
		return
	player_in_area = true


func _on_building_area_body_exited(body: Node2D) -> void:
	if !body.is_in_group("player"):
		return
	player_in_area = false

func _on_unlock_timer_timeout() -> void : 
	player_in_area = false
	clear_circle()
	unlockable_shape.call_deferred("set_disabled", true)
	unlock_bar.hide()
	
	for i in building_data.value:
		var object : Node2D = building_data.spawnable.instantiate()
		get_parent().add_child(object)
		object.bank_launch_spawn(spawn_center.global_position, pick_dollar_landing())

func pick_dollar_landing() -> Vector2:
	var r_min : float = GeoTools.circumscribed_radius(footprint, CELL_SIZE)
	var r_max : float = unlockable_shape.shape.radius - DOLLAR_EDGE_PAD
	r_max = max(r_max, r_min + 1.0)
	return GeoTools.random_point_in_annulus(spawn_center.global_position, r_min, r_max)
