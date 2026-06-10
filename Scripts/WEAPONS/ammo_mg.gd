class_name  AmmoMG
extends Area2D

@export var bullet_data: WeaponData

var speed : float
var max_range : float
var damages : int
var damages_upgrade : int
var current_lvl : int
var max_lvl : int

var velocity : Vector2
var start_position : Vector2

@onready var parent_weapon: Node2D = $"/root/World/Car/Weapons/Minigun"
@onready var camera_2d: Camera2D = $/root/World/Car/Camera2D

var game_paused:= false

var is_active:= false

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	max_lvl = bullet_data.max_level
	
	#bullet_data.init_stats()
	speed = bullet_data.speed.get_value()
	max_range = bullet_data.atk_range.get_value()
	damages = int(bullet_data.dmg.get_value())
	

func _process(_delta: float) -> void:
	if !bullet_data.weapon_is_active:
		desactivate()


func fire(from_position: Vector2, direction: Vector2, angle: float) -> void:
	global_position = from_position
	start_position = from_position
	velocity = direction.normalized() * bullet_data.speed.get_value()
	self.show()
	is_active = true
	set_physics_process(true)
	rotation = angle
	camera_2d.screen_shake(5,0.5)


func _physics_process(delta: float) -> void:
	if !game_paused:
		var next_position : Vector2 = global_position + velocity * delta
		global_position = next_position
		
	
	if abs(self.global_position - start_position).length() > bullet_data.atk_range.get_value():
		if !game_paused:
			desactivate()


func _on_area_hit(area: Area2D) -> void:
	if "get_damages" in area and area.is_in_group("ennemies") and is_active:
		area.get_damages(bullet_data.dmg.get_value())
		bullet_data.total_damages_dealt += int(bullet_data.dmg.get_value())

		desactivate()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("walls"):
		desactivate()


func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause

func desactivate()-> void:
	hide()
	is_active = false
	set_process(false)
	set_physics_process(false)
	global_position = Vector2(-10,-10)
	if parent_weapon: parent_weapon.add_bullet_to_pool(self)


func activate() -> void :
	if !is_active:
		is_active = true
		visible = true
		set_process(true)
		set_physics_process(true)

func on_level_up() -> void : 
	pass
