extends Area2D

@export var flamer_data : WeaponData
var dmg : int

var cool_down : float
var current_lvl : int
var max_lvl : int
var enemies_can_burn: bool = false
var is_firing: bool = false
var burning: bool = true
var targets: Array[Node2D]


@onready var player: Sprite2D =  $"/root/World/Car/CarSprite"


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
	dmg = roundi(flamer_data.dmg + (current_lvl * .1 * 28)) #améliorer la formule d'augmentation des dégats

	
	if is_firing:
		#sprite.rotation = player.rotation + deg_to_rad(90)

		sprite.show()
		burn_enemies()
	
	if !is_firing:
		sprite.hide()
	
	if is_firing and game_paused and !fire_rate.paused:
		fire_rate.paused = true
	
	if is_firing and !game_paused and fire_rate.paused:
		fire_rate.paused = false
	
func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
	if game_paused and sprite.is_playing():
		sprite.pause()
	if !game_paused and !sprite.is_playing():
		sprite.play()

func throw_fire() -> void:
	if !flamer_data.weapon_is_active: return
	if flamer_data.weapon_is_active:
		is_firing = true
		sprite.play("huge_fire_start")
		await get_tree().create_timer(0.2).timeout
		await get_tree().create_timer(0.3).timeout
		enemies_can_burn = true
		sprite.play("huge_fire_cycle")



func burn_enemies() -> void:
	if !targets.is_empty() and burning:
		burning = false
		burn_rate.start()
		for i in targets.size():
			if enemies_can_burn:
				targets[i].get_damages(dmg)
		burning = false

func _on_area_entered(area: Area2D) -> void:
		if area.is_in_group("ennemies") and "get_damages" in area.get_parent():
			targets.append(area.get_parent())
			throw_fire()
		else : return


func _on_area_exited(area: Area2D) -> void:
		if area.is_in_group("ennemies") and "get_damages" in area.get_parent():
			targets.erase(area.get_parent())
			if targets.is_empty():
				enemies_can_burn = false
				await get_tree().create_timer(0.5).timeout
				sprite.play("huge_fire_end")
				await get_tree().create_timer(0.5).timeout
				is_firing = false
				targets.clear()
		else : return

func _on_burn_rate_timeout() -> void:
	burning = true
	
