extends Area2D

@export var flamer_data : WeaponData
var dmg

var cool_down
var current_lvl
var max_lvl
var fire:= true
var is_firing:= false
var burning: = true
var targets: Array[Node2D]


@onready var player: Sprite2D =  $"/root/World/Car/Sprite2D"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_pol: CollisionPolygon2D = $CollisionPolygon2D

@onready var fire_rate: Timer = $FireRate
@onready var burn_rate: Timer = $BurnRate

@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:=false


func _ready() -> void:
	gm_scene.game_paused.connect(_on_game_paused)
	fire_rate.wait_time = flamer_data.fire_rate
	cool_down = flamer_data.cool_down
	max_lvl = flamer_data.max_level
	

func _process(_delta: float) -> void:
	current_lvl = clampi(flamer_data.current_level,0,max_lvl)
	dmg = flamer_data.dmg + (current_lvl * .1 * 28) #améliorer la formule d'augmentation des dégats
	if fire:
		throw_fire()
	
	if is_firing:
		sprite.rotation = player.rotation + deg_to_rad(-90)
		collision_pol.set_deferred("disabled", false)
		burn_enemies()
	
	if !is_firing:
		collision_pol.set_deferred("disabled",true)

		#print("flame rotation = ",flameVFX.rotation," / player rotation = ",player.rotation)
	
	if is_firing and game_paused and !fire_rate.paused:
		fire_rate.paused = true
	
	if is_firing and !game_paused and fire_rate.paused:
		fire_rate.paused = false
	
func _on_game_paused(game_on_pause) -> void:
	game_paused = game_on_pause

func throw_fire():
	if !fire: return
	fire = false
	is_firing = true
	fire_rate.start()
	sprite.play("fire_start")
	await get_tree().create_timer(0.5).timeout
	sprite.play("fire_cycle")

func _on_fire_rate_timeout() -> void:
	sprite.play("fire_end")
	is_firing = false
	targets.clear()
	await get_tree().create_timer(cool_down).timeout
	fire = true

func burn_enemies():
	if !targets.is_empty() and burning:
		burning = false
		burn_rate.start()
		for i in targets.size():
			targets[i].get_damages(dmg)
		burning = false

func _on_area_entered(area: Area2D) -> void:
		if area.is_in_group("ennemies") and "get_damages" in area.get_parent():
			targets.append(area.get_parent())
		else : return


func _on_area_exited(area: Area2D) -> void:
		if area.is_in_group("ennemies") and "get_damages" in area.get_parent():
			targets.erase(area.get_parent())
		else : return

func _on_burn_rate_timeout() -> void:
	burning = true
	
