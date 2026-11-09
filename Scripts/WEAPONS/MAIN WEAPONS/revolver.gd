extends Node2D

const BULLET = preload("uid://dww6b787qn3x0")

@export var revolver_data: WeaponData

@onready var fire_rate: Timer = $FireRate
var fire_rate_upgrade : float
@onready var fire_point: Marker2D = $FirePoint
@onready var car: CharacterBody2D = $/root/World/Car
@onready var fire_range: CollisionShape2D = $FireRange/FireRangeShape
@onready var shot_sfx: AudioStreamPlayer2D = $ShotSFX

# ---- MANEUVER-DRIVEN FIRE -----
@export var auto_fire: bool = false   # legacy auto-targeting (off: fire on maneuvers only)
@export var sfx_min_interval: float = 0.1   # one shot sound at most every N seconds
@export var sfx_polyphony: int = 4          # overlapping shot sounds before the oldest is cut

@export var critical_multiplier: float = 2.0
@export var muzzle_flash_count: int = 3
@export var oval_half_length: float = 24.0
@export var oval_half_width: float = 12.0
@export var oval_center_offset: Vector2 = Vector2.ZERO


var combo_multiplier: float = 1.0

# ---- DEAD EYE SALVO: one aimed shot after the other -----
var shots_left: int = 0
var shot_count: int = 0
var shot_index: int = 0
var shot_timer: float = 0.0
var shot_interval: float = 0.0          #salvo spread over the maneuver duration, like ManeuverSalvo
var shot_damage_multiplier: float = 1.0
var arc_center: float = 0.0
var arc_width: float = TAU
var shot_targets: Array[Node2D] = []

var muzzle_flashes: Array[MuzzleFlashVFX] = []
var muzzle_flash_index: int = 0


var sfx_cooldown: float = 0.0
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
	SignalManager.maneuver_performed.connect(_on_maneuver_performed)
	SignalManager.combo_changed.connect(_on_combo_changed)
	SignalManager.maneuver_salvo_repeated.connect(_on_maneuver_performed)

	shot_sfx.stream = revolver_data.weapon_sfx
	shot_sfx.max_polyphony = sfx_polyphony
	fire_rate.wait_time = revolver_data.base_fire_rate
	max_lvl = revolver_data.max_level
	
	for i: int in maxi(muzzle_flash_count, 1):
		var muzzle_flash: MuzzleFlashVFX = revolver_data.muzzle_flash.instantiate() as MuzzleFlashVFX
		add_child(muzzle_flash)
		muzzle_flashes.append(muzzle_flash)
	
	create_bullet_pool(max_bullet_count)
	
	nb_ammo = int(revolver_data.nb_ammo.get_value())
	fire_rate.wait_time = revolver_data.fire_rate.get_value()
	fire_range.shape.radius = revolver_data.weapon_ammo_res.atk_range.get_value()
	revolver_data.weapon_ammo_res.atk_range.stat_adjusted.connect(_on_bullet_range_modified)
	revolver_data.fire_rate.stat_adjusted.connect(_on_fire_rate_modified)


func _process(_delta: float) -> void:
	if !game_paused and auto_fire:
		shoot_from_pool()
	
	if !revolver_data.weapon_is_active:
		desactivate()

func _physics_process(delta: float) -> void:
	global_position = get_parent().global_position
	if game_paused:
		return
	sfx_cooldown -= delta
	if shots_left <= 0:
		return
	shot_timer -= delta
	# a zero duration fires the whole salvo at once
	while shots_left > 0 and shot_timer <= 0.0:
		_fire_aimed_shot()
		shots_left -= 1
		shot_timer += shot_interval
		if sfx_cooldown <= 0.0:
			shot_sfx.play()
			sfx_cooldown = sfx_min_interval

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
		
		if revolver_data.nb_projectile.get_value() > 1 : 
			for i in  range(1,revolver_data.nb_projectile.get_value() + 1):
				var perp : Vector2 = dir.rotated(PI / 2)
				var parallel_offset : float = 10 * i
				var parallel_origin : Vector2 = fire_point.global_position + perp * parallel_offset
				var bullet2 : AmmoREV = get_bullet_from_pool()
				bullet2.fire(parallel_origin,dir,angle)
		_play_muzzle_flash(fire_point.global_position, angle)
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

func _on_bullet_range_modified(new_value: float) -> void:
	fire_range.shape.radius = new_value

func _on_combo_changed(multiplier: float, _combo_count: int) -> void:
	combo_multiplier = multiplier


func _on_maneuver_performed(maneuver_type: ManeuverManager.Type, intensity: float, drift_level: int, is_amplified: bool, attack_angle: float) -> void:
	if !revolver_data.weapon_is_active or game_paused or LoadoutManager.get_weapon(maneuver_type) != revolver_data:
		return
	var pattern: Vector3 = ManeuverManager.get_pattern(maneuver_type)
	# Zone maneuver: no projectiles (same rule as ManeuverSalvo)
	if pattern.z < 0.0:
		return
	shot_count = revolver_data.get_salvo_count(maneuver_type, intensity, drift_level, is_amplified, combo_multiplier)
	shots_left = shot_count
	shot_index = 0
	shot_timer = 0.0
	shot_interval = pattern.z / shot_count
	arc_center = attack_angle
	arc_width = pattern.y
	shot_damage_multiplier = revolver_data.get_combo_damage_multiplier(combo_multiplier, maneuver_type)
	if is_amplified:
		shot_damage_multiplier *= critical_multiplier
	shot_targets.clear()


## Aimed at the nearest enemy of the arc. Nothing in the arc: fired anyway, spread over the arc
func _fire_aimed_shot() -> void:
	var car_rotation: float = car.global_rotation
	var oval_center: Vector2 = car.global_position + oval_center_offset.rotated(car_rotation)
	var target: Node2D = _pick_target(oval_center)
	var angle: float
	if target != null:
		angle = oval_center.direction_to(target.global_position).angle()
	else:
		angle = ManeuverManager.get_spread_angle(shot_index, shot_count, arc_width, arc_center)
	var start_position: Vector2 = oval_center + _get_oval_offset(angle - car_rotation).rotated(car_rotation)
	# From its start on the oval straight to the target
	var direction: Vector2 = start_position.direction_to(target.global_position) if target != null else Vector2.RIGHT.rotated(angle)
	var bullet: AmmoREV = get_bullet_from_pool()
	bullet.fire(start_position, direction, direction.angle(), shot_damage_multiplier)
	shot_index += 1
	_play_muzzle_flash(start_position, direction.angle())


## Nearest enemy in range and in the arc not aimed at yet in this salvo.
## All of them aimed at: starts again from the nearest
func _pick_target(origin: Vector2) -> Node2D:
	var nearest_new: Node2D = null
	var nearest_new_distance: float = INF
	var nearest_any: Node2D = null
	var nearest_any_distance: float = INF
	for i: int in range(targets.size() - 1, -1, -1):
		var target: Node2D = targets[i]
		if !is_instance_valid(target):
			targets.remove_at(i)
			continue
		if !_is_in_arc(origin, target.global_position):
			continue
		var distance: float = origin.distance_squared_to(target.global_position)
		if distance < nearest_any_distance:
			nearest_any = target
			nearest_any_distance = distance
		if distance < nearest_new_distance and !shot_targets.has(target):
			nearest_new = target
			nearest_new_distance = distance
	if nearest_new == null and nearest_any != null:
		shot_targets.clear()
		nearest_new = nearest_any
	if nearest_new != null:
		shot_targets.append(nearest_new)
	return nearest_new


func _is_in_arc(origin: Vector2, target_position: Vector2) -> bool:
	# Full turn maneuver: every enemy in range
	if arc_width >= TAU - 0.01:
		return true
	var target_angle: float = origin.direction_to(target_position).angle()
	return absf(angle_difference(arc_center, target_angle)) <= arc_width * 0.5


func _get_oval_offset(local_angle: float) -> Vector2:
	var local_direction: Vector2 = Vector2.RIGHT.rotated(local_angle)
	var x_ratio: float = local_direction.x / maxf(oval_half_length, 1.0)
	var y_ratio: float = local_direction.y / maxf(oval_half_width, 1.0)
	return local_direction / sqrt(x_ratio * x_ratio + y_ratio * y_ratio)


func _play_muzzle_flash(start_position: Vector2, angle: float) -> void:
	var muzzle_flash: MuzzleFlashVFX = muzzle_flashes[muzzle_flash_index]
	muzzle_flash_index = (muzzle_flash_index + 1) % muzzle_flashes.size()
	muzzle_flash.activate(start_position, angle)
