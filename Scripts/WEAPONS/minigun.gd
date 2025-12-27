extends Node2D

const BULLET = preload("uid://doe8o0sd0xuas")

@export var minigun_data: WeaponData

@onready var timer: Timer = $FireRate
@onready var fire_point: Marker2D = $FirePoint

@onready var player: CharacterBody2D = $/root/World/Car

var nb_ammo: int
var nb_bullet: = 0
var cool_down : float
#var fire_rate : float
var current_lvl: int
var max_lvl : int
var can_shoot := true
var next_bullet := false

var max_bullet_count : int = 400
var bullet_pool : Array[AmmoMG]
var bullet_index : int = 0
var bullet_spread_angle: float = 10

var bonus_bullet: int = 0

func _ready() -> void:
	if minigun_data.bonus:
		bonus_bullet = 35
	else : bonus_bullet = 0
	timer.wait_time = minigun_data.fire_rate
	cool_down = minigun_data.cool_down
	max_lvl = minigun_data.max_level
	create_bullet_pool(max_bullet_count)
	can_shoot = true


func _process(_delta: float) -> void:
	current_lvl = clampi(minigun_data.current_level,0,max_lvl)
	nb_ammo = minigun_data.nb_ammo + current_lvl + bonus_bullet
	if can_shoot:
		shoot_from_pool()

func _physics_process(_delta: float) -> void:
	global_position = get_parent().global_position

func shoot_from_pool()-> void :
	can_shoot = false
	timer.start()
	if next_bullet:
		next_bullet = false
		if nb_bullet <= nb_ammo:
			var angle : float = player.rotation
			var bullet = get_bullet_from_pool()
			var dir = Vector2.RIGHT.rotated(angle)
			bullet.fire(fire_point.global_position,dir,angle)
			print(nb_bullet)
	

func _on_fire_rate_timeout() -> void:
	if nb_bullet <= nb_ammo:
		next_bullet = true
		nb_bullet += 1
		shoot_from_pool()
	else :
		await get_tree().create_timer(cool_down).timeout
		nb_bullet = 0
		can_shoot = true
		next_bullet = true
		
		

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

func create_bullet_pool(nb_bullets: int):
	for i in nb_bullets:
		var bullet : AmmoMG = BULLET.instantiate()
		bullet.desactivate()
		get_node("/root/World/Bullets").add_child(bullet)
		bullet_pool.append(bullet)
	print(bullet_pool.size(), " arrows have been pooled")

	
func add_bullet_to_pool(bullet: AmmoMG):
	bullet_pool.append(bullet)
	#print("enemy desactivated - pool size : ",enemies_pool.size())
