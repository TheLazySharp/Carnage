extends Area2D

@export var flame_data : WeaponData
var damages : int
var damages_upgrade : int

var current_lvl : int
var max_lvl : int
var enemies_can_burn: bool = false
var is_firing: bool = false
var burning: bool = true
var targets: Array[Node2D]


@onready var player: Sprite2D =  $"/root/World/Car/CarSprite"
@onready var flame_sfx: AudioStreamPlayer2D = $FlameSfx

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_pol: CollisionPolygon2D = $CollisionPolygon2D

@onready var burn_rate: Timer = $BurnRate

var game_paused: bool =false


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)

	max_lvl = flame_data.max_level
	flame_sfx.stream = flame_data.weapon_sfx
	damages = int(flame_data.dmg.get_value())

func _process(_delta: float) -> void:

	if !flame_data.weapon_is_active:
		desactivate()

	if is_firing:

		sprite.show()
		burn_enemies()
	
	if !is_firing:
		sprite.hide()
	
func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
	if game_paused and sprite.is_playing():
		sprite.pause()
	if !game_paused and !sprite.is_playing():
		sprite.play()

func throw_fire() -> void:
	if !flame_data.weapon_is_active: return
	if flame_data.weapon_is_active:
		is_firing = true
		flame_sfx.play()
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
				targets[i].get_damages(flame_data.dmg.get_value())
				flame_data.total_damages_dealt += int(flame_data.dmg.get_value())
		burning = false

func _on_area_entered(area: Area2D) -> void:
		if area.is_in_group("ennemies") and "get_damages" in area.get_parent():
			targets.append(area.get_parent())
			if targets.size() <= 1:
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
			flame_sfx.stop()
			is_firing = false
			targets.clear()
	else : return

func _on_burn_rate_timeout() -> void:
	burning = true

func desactivate() -> void:
	sprite.stop()
	hide()
	is_firing = false
	burning = false
	enemies_can_burn = false
	targets.clear()
