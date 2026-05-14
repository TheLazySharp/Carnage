extends Node2D

const BULLET = preload("uid://dww6b787qn3x0")


@export var revolver_data: WeaponData

@onready var fire_rate: Timer = $FireRate
var fire_rate_upgrade : float
@onready var fire_point: Marker2D = $FirePoint

@onready var fire_range: CollisionShape2D = $FireRange/FireRangeShape
@onready var shot_sfx: AudioStreamPlayer2D = $ShotSFX
@onready var muzzle_flash: AnimatedSprite2D = $MuzzleFlash


var game_paused:=false

var nb_ammo: int
var current_lvl: int
var max_lvl : int
var can_shoot : = true

var max_bullet_count : int = 200
var bullet_pool : Array[AmmoREV]
var bonus_bullet: int = 0
var targets: Array[Node2D]


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	StatsManager.stats_updated.connect(_on_stats_updated)

	shot_sfx.stream = revolver_data.weapon_sfx
	fire_rate.wait_time = revolver_data.base_fire_rate
	max_lvl = revolver_data.max_level
	#_on_stats_updated()
	create_bullet_pool(max_bullet_count)
	muzzle_flash.hide()
	
	revolver_data.init_stats()
	
	nb_ammo = revolver_data.nb_ammo.get_value()
	fire_rate.wait_time = revolver_data.fire_rate.get_value()
	fire_range.shape.radius = revolver_data.radius.get_value()
	revolver_data.fire_rate.stat_adjusted.connect(_on_fire_rate_modified)
	
	


func _process(_delta: float) -> void:
	if !game_paused:
		shoot_from_pool()
	
	if !revolver_data.weapon_is_active:
		desactivate()

func _physics_process(_delta: float) -> void:
	global_position = get_parent().global_position

func shoot_from_pool()-> void :
	if !can_shoot or !revolver_data.weapon_is_active: return
	if targets.is_empty(): return
	elif revolver_data.weapon_is_active:
		can_shoot = false
		fire_rate.start()

		var target : Node2D = get_nearest_target()
		var bullet : AmmoREV = get_bullet_from_pool()
		var dir : Vector2= fire_point.global_position.direction_to(target.global_position)
		var angle : float = dir.angle()
		bullet.fire(fire_point.global_position,dir,angle)
		#muzzle_flash.rotation = angle
		muzzle_flash.show()
		muzzle_flash.play("fire")
		shot_sfx.play()
		

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
	var nearest_target : Node2D = targets[0]
	var shorter_distance : float = nearest_target.global_position.distance_squared_to(fire_point.global_position)
	for i in targets.size():
		var target : Node2D= targets[i]
		var distance : float = target.global_position.distance_squared_to(fire_point.global_position)
		if distance < shorter_distance :
			nearest_target = target
			shorter_distance = distance
	return nearest_target

func create_bullet_pool(nb_bullets: int) -> void:
	for i in nb_bullets:
		var bullet : AmmoREV = BULLET.instantiate()
		bullet.desactivate()
		get_node("/root/World/Bullets").add_child(bullet)
		bullet_pool.append(bullet)
	print(bullet_pool.size(), " bullets have been pooled")

	
func add_bullet_to_pool(bullet: AmmoREV) -> void:
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

func _on_game_paused(game_on_pause :bool) -> void:
	game_paused = game_on_pause
	
func desactivate() -> void :
	can_shoot = false
	targets.clear()
	fire_rate.stop()
	
	
func _on_fire_rate_modified(new_value: float) -> void : 
	fire_rate.wait_time = new_value

func _on_stats_updated() -> void : 
	pass
	#current_lvl = clampi(revolver_data.current_level,0,max_lvl)
	#fire_rate.wait_time = (revolver_data.base_fire_rate - current_lvl * 0.02) * LuckyCharmsManager. all_fire_rate_bonus * LuckyCharmsManager.short_range_fire_rate_bonus
	#fire_rate_upgrade = (revolver_data.base_fire_rate - (current_lvl + 1) * 0.02) * LuckyCharmsManager. all_fire_rate_bonus * LuckyCharmsManager.short_range_fire_rate_bonus
	#revolver_data.fire_rate = fire_rate.wait_time
	#revolver_data.fire_rate_upgrade = fire_rate_upgrade
	#
	#fire_range.shape.radius = revolver_data.base_radius
