class_name  AmmoREV
extends Area2D

@export var bullet_data: WeaponData

var speed : float
var max_range : float
var damages : int
var damages_upgrade : int
var current_lvl : int
var max_lvl : int
#@onready var trail: CPUParticles2D = $VFX

var velocity : Vector2
var start_position : Vector2

@onready var parent_weapon: Node2D = $/root/World/Car/Weapons/Revolver



var game_paused:= false

var is_active:= false

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	max_lvl = bullet_data.max_level

	damages = int(bullet_data.dmg.get_value())
	max_range = bullet_data.atk_range.get_value()
	speed = bullet_data.speed.get_value()
	

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




func _physics_process(delta: float) -> void:
	if not game_paused:
		var next_position : Vector2 = global_position + velocity * delta
		global_position = next_position

	if start_position.distance_to(global_position) > bullet_data.atk_range.get_value():
		if not game_paused:
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



func activate()->void:
	if !is_active:
		is_active = true
		visible = true
		set_process(true)
		set_physics_process(true)


func _on_area_entered(area: Area2D) -> void:
	if "get_damages" in area and area.is_in_group("ennemies") and is_active:
		area.get_damages(bullet_data.dmg.get_value())
		bullet_data.total_damages_dealt += int(bullet_data.dmg.get_value())
		desactivate()
	elif area.is_in_group("walls"):
		desactivate()
