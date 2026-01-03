extends Node2D

const BULLET = preload("uid://dww6b787qn3x0")


@export var slingshot_data: WeaponData

@onready var fire_rate: Timer = $FireRate
@onready var fire_point: Marker2D = $FirePoint

@onready var fire_range: CollisionShape2D = $FireRange/FireRangeShape

var nb_ammo: int
var current_lvl: int
var max_lvl : int
var can_shoot :=true

var max_bullet_count : int = 200
var bullet_pool : Array[AmmoREV]
var bonus_bullet: int = 0
var targets: Array[Node2D]


func _ready() -> void:
	if slingshot_data.bonus:
		bonus_bullet = 35
	else : bonus_bullet = 0
	fire_rate.wait_time = slingshot_data.fire_rate
	max_lvl = slingshot_data.max_level
	fire_range.shape.radius = slingshot_data.radius
	create_bullet_pool(max_bullet_count)

func _process(_delta: float) -> void:
	current_lvl = clampi(slingshot_data.current_level,0,max_lvl)
	nb_ammo = slingshot_data.nb_ammo + current_lvl + bonus_bullet
	shoot_from_pool()

func _physics_process(_delta: float) -> void:
	global_position = get_parent().global_position

func shoot_from_pool()-> void :
	if !can_shoot: return
	if targets.is_empty(): return
	else:
		can_shoot = false
		fire_rate.start()

		var target = get_nearest_target()
		var bullet = get_bullet_from_pool()
		var dir = fire_point.global_position.direction_to(target.global_position)
		var angle = dir.angle()
		bullet.fire(fire_point.global_position,dir,angle)

func _on_fire_rate_timeout() -> void:
	can_shoot = true
	
func get_bullet_from_pool() -> AmmoREV:
	var bullet : AmmoREV
	if bullet_pool.is_empty():
		create_bullet_pool(1)
		bullet = bullet_pool[0]
	else:
		bullet = bullet_pool[0] 
		bullet_pool.remove_at(0)
	return bullet

func get_nearest_target() -> Node2D:
	if targets.is_empty(): return
	var nearest_target = targets[0]
	var shorter_distance = nearest_target.global_position.distance_squared_to(fire_point.global_position)
	for i in targets.size():
		var target = targets[i]
		var distance = target.global_position.distance_squared_to(fire_point.global_position)
		if distance < shorter_distance :
			nearest_target = target
			shorter_distance = distance
	return nearest_target

func create_bullet_pool(nb_bullets: int):
	for i in nb_bullets:
		var bullet : AmmoREV = BULLET.instantiate()
		bullet.desactivate()
		get_node("/root/World/Bullets").add_child(bullet)
		bullet_pool.append(bullet)
	print(bullet_pool.size(), " bullets have been pooled")

	
func add_bullet_to_pool(bullet: AmmoREV):
	bullet_pool.append(bullet)
	#print("enemy desactivated - pool size : ",enemies_pool.size())


func _on_fire_range_entered(area: Area2D) -> void:
	if area.is_in_group("ennemies"):
		targets.append(area)
		#print("enemy in range - total = ",targets.size())


func _on_fire_range_exited(area: Area2D) -> void:
		if area.is_in_group("ennemies"):
			targets.erase(area)
			#print("enemy exit - total = ",targets.size())
