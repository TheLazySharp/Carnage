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
var fire_rate : float

var nb_bullet: = 0
var is_firing: bool = false

var max_bullet_count : int = 400
var bullet_pool : Array[AmmoMG]
var bullet_index : int = 0
var bullet_spread_angle: float = 10
var bonus_bullet: int = 0

var target_pos: Vector2
var assign_target : bool = true
var enemies_in_range : Array[Area2D] = []
var current_target : Area2D = null

var game_paused: bool = false

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	
	shot_sfx.stream = minigun_data.weapon_sfx
	create_bullet_pool(max_bullet_count)
	muzzle_flash.hide()

	nb_ammo = minigun_data.nb_ammo.get_value()
	timer.wait_time = minigun_data.fire_rate.get_value()
	
	minigun_data.fire_rate.stat_adjusted.connect(_on_fire_rate_modified)

func _process(_delta: float) -> void:
		
	if is_firing and game_paused and !timer.paused:
		timer.paused = true
	
	if is_firing and !game_paused and timer.paused:
		timer.paused = false

	if !minigun_data.weapon_is_active:
		desactivate()

func _physics_process(_delta: float) -> void:
	#global_position = Vector2(get_parent().global_position.x, get_parent().global_position.y - offset_Y)
	pass

func fire_bullet(p_target_pos : Vector2)-> void :
	var bullet : AmmoMG = get_bullet_from_pool()
	var dir : Vector2 = fire_point.global_position.direction_to(p_target_pos)
	var angle : float = dir.angle()
	bullet.fire(fire_point.global_position,dir,angle)
	
	if minigun_data.nb_projectile.get_value() > 1 : 
		for i in  range(1,minigun_data.nb_projectile.get_value()):
			var perp : Vector2 = dir.rotated(PI / 2)
			var parallel_offset : float = 20 * i
			var parallel_origin : Vector2 = fire_point.global_position + perp * parallel_offset
			var bullet2 : AmmoMG = get_bullet_from_pool()
			bullet2.fire(parallel_origin,dir,angle)

	muzzle_flash.rotation = angle + deg_to_rad(90)
	muzzle_flash.show()
	muzzle_flash.play("fire")
	shot_sfx.play()

func _on_fire_rate_timeout() -> void:
	if game_paused:
		return
	
	if !is_instance_valid(current_target):
		current_target = get_valid_target()
		if current_target == null:
			end_burst()
			return
	
	if nb_bullet < minigun_data.nb_ammo.get_value():
		nb_bullet += 1
		fire_bullet(current_target.global_position)
	else:
		end_burst()

func end_burst() -> void:
	timer.stop()
	is_firing = false
	nb_bullet = 0
	try_start_burst()

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

func add_bullet_to_pool(bullet: AmmoMG) -> void:
	bullet_pool.append(bullet)

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause

func desactivate() -> void:
	timer.stop()
	is_firing = false
	nb_bullet = 0

func _on_fire_rate_modified(new_value: float) -> void : 
	timer.wait_time = new_value

func _on_range_area_entered(area: Area2D) -> void:
	if area.is_in_group("ennemies"):
		enemies_in_range.append(area)
		try_start_burst()

func _on_range_area_exited(area: Area2D) -> void:
	enemies_in_range.erase(area)

func try_start_burst() -> void:
	if is_firing or !minigun_data.weapon_is_active or game_paused:
		return
	current_target = get_valid_target()
	if current_target == null:
		return
	is_firing = true
	nb_bullet = 0
	timer.start()

func get_valid_target() -> Area2D:
	for i in range(enemies_in_range.size() - 1, -1, -1):
		if !is_instance_valid(enemies_in_range[i]):
			enemies_in_range.remove_at(i)
	if enemies_in_range.is_empty():
		return null
	return enemies_in_range[0]
