extends Node2D

const BULLET = preload("uid://doe8o0sd0xuas")

@export var minigun_data: WeaponData

@onready var timer: Timer = $FireRate
@onready var fire_point: Marker2D = $FirePoint

@onready var player: CharacterBody2D = $/root/World/Car
@onready var shot_sfx: AudioStreamPlayer2D = $ShotSfx
@onready var muzzle_flash: AnimatedSprite2D = $MuzzleFlash

# ---- MAIN STATS -----
var nb_ammo: float
var cool_down : float
var fire_rate : float

var nb_ammo_upgrade: int
var nb_bullet: = 0
var current_lvl: int
var max_lvl : int
var can_shoot := true
var next_bullet := false
#var raycastON:= false
var is_firing:= false

var max_bullet_count : int = 400
var bullet_pool : Array[AmmoMG]
var bullet_index : int = 0
var bullet_spread_angle: float = 10
var bonus_bullet: int = 0

var target_pos: Vector2
var assign_target : bool = true

#@onready var ray_cast_2d: RayCast2D = $RayCast2D
#@onready var sprite_sight: Sprite2D = $SpriteSight

var offset_Y := 12

var game_paused:=false

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	
	shot_sfx.stream = minigun_data.weapon_sfx
	max_lvl = minigun_data.max_level
	create_bullet_pool(max_bullet_count)
	can_shoot = true
	next_bullet = false
	#raycastON = true
	muzzle_flash.hide()

	nb_ammo = minigun_data.nb_ammo.get_value()
	timer.wait_time = minigun_data.fire_rate.get_value()
	
	minigun_data.fire_rate.stat_adjusted.connect(_on_fire_rate_modified)


func _process(_delta: float) -> void:
	#if raycastON and ray_cast_2d.is_colliding():
		#if !is_instance_valid(ray_cast_2d.get_collider()):
			#return
		#if ray_cast_2d.get_collider().is_in_group("ennemies"):
			#can_shoot = true
			#raycastON = false
			#shoot_from_pool()
		
	if is_firing and game_paused and !timer.paused:
		timer.paused = true
	
	if is_firing and !game_paused and timer.paused:
		timer.paused = false

	if !minigun_data.weapon_is_active:
		desactivate()


func _physics_process(_delta: float) -> void:
	global_position = Vector2(get_parent().global_position.x, get_parent().global_position.y - offset_Y)
	
	
	
func shoot_from_pool()-> void :
	if !can_shoot or !minigun_data.weapon_is_active : 
		return
	if minigun_data.weapon_is_active:
		timer.start()
		is_firing = true
		if next_bullet and !game_paused:
			next_bullet = false
			if nb_bullet <= minigun_data.nb_ammo.get_value():
				var bullet : AmmoMG = get_bullet_from_pool()
				var dir : Vector2 = fire_point.global_position.direction_to(target_pos)
				var angle : float = dir.angle()
				bullet.fire(fire_point.global_position,dir,angle)
				muzzle_flash.rotate(angle + deg_to_rad(90))
				muzzle_flash.show()
				muzzle_flash.play("fire")
				shot_sfx.play()
		

func _on_fire_rate_timeout() -> void:
	if nb_bullet <= minigun_data.nb_ammo.get_value():
		next_bullet = true
		nb_bullet += 1
		shoot_from_pool()
	else :
		nb_bullet = 0
		can_shoot = false
		is_firing = false
		next_bullet = true
		assign_target = true
		#raycastON = true


func get_bullet_from_pool() -> AmmoMG:
	var bullet : AmmoMG
	if bullet_pool.is_empty():
		print("bullet pool empty")
		create_bullet_pool(1)
		bullet = bullet_pool[0]
	else:
		bullet = bullet_pool[0] 
		bullet_pool.remove_at(0)
	return bullet

func create_bullet_pool(nb_bullets: int) -> void:
	for i in nb_bullets:
		var bullet : AmmoMG = BULLET.instantiate()
		bullet.desactivate()
		get_node("/root/World/Bullets").add_child(bullet)
		bullet_pool.append(bullet)
	#print(bullet_pool.size(), "Mg bullets have been pooled")

func add_bullet_to_pool(bullet: AmmoMG) -> void:
	bullet_pool.append(bullet)

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause

func desactivate() -> void:
	can_shoot = false
	is_firing = false
	next_bullet = false
	timer.stop()


func _on_fire_rate_modified(new_value: float) -> void : 
	timer.wait_time = new_value


func _on_range_area_entered(area: Area2D) -> void:
	if area.is_in_group("ennemies") and assign_target:
		assign_target = false
		target_pos = area.global_position
		can_shoot = true
		shoot_from_pool()
