extends Node2D

const BULLET = preload("uid://bjuws4ysoivbu")

@export var bow_data: WeaponData


@onready var timer: Timer = $FireRate
@onready var fire_point: Marker2D = $FirePoint

var nb_ammo: int
var current_lvl: int
var max_lvl : int
var can_shoot :=true

var max_bullet_count : int = 400
var bullet_pool : Array[Bullet]
var bullet_index : int = 0
var bullet_spread_angle: float = 10

var bonus_bullet: int = 0

func _ready() -> void:
	if bow_data.bonus:
		bonus_bullet = 35
	else : bonus_bullet = 0
	timer.wait_time = bow_data.fire_rate
	max_lvl = bow_data.max_level
	create_bullet_pool(max_bullet_count)

func _process(_delta: float) -> void:
	current_lvl = clampi(bow_data.current_level,0,max_lvl)
	nb_ammo = bow_data.nb_ammo + current_lvl + bonus_bullet


func _physics_process(_delta: float) -> void:
	global_position = get_parent().global_position

func shoot_from_pool()-> void :
	if !can_shoot: return
	can_shoot = false
	timer.start()
	var start_angle = -((nb_ammo - 1) * bullet_spread_angle) * .5
	print("nb bullet before fire : ",bullet_pool.size())
	for i in nb_ammo:
		var angle : float = deg_to_rad(start_angle + i * bullet_spread_angle)
		var bullet = get_bullet_from_pool()
		var dir = Vector2.UP.rotated(angle)
		bullet.fire(fire_point.global_position,dir,angle)
		#print(i," / ",nb_ammo, " / ", bullet.visible)
	print("nb bullet after fire : ",bullet_pool.size())


func _on_fire_rate_timeout() -> void:
	can_shoot = true

func get_bullet_from_pool() -> Bullet:
	var bullet : Bullet
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
		var bullet : Bullet = BULLET.instantiate()
		bullet.desactivate()
		get_node("/root/World/Bullets").add_child(bullet)
		bullet_pool.append(bullet)
	print(bullet_pool.size(), " arrows have been pooled")

	
func add_bullet_to_pool(bullet: Bullet):
	bullet_pool.append(bullet)
	#print("enemy desactivated - pool size : ",enemies_pool.size())
