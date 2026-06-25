extends Node2D

@export var bat_data : WeaponData
var damages : int
var damages_upgrade : int
var current_lvl : int
var max_lvl : int
var timer : float
@onready var smash_shape: CollisionShape2D = $SmashZone/SmashShape
@onready var whoosh_sfx: AudioStreamPlayer = $WhooshSFX
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var game_paused : bool = false


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	max_lvl = bat_data.max_level
	damages = int(bat_data.dmg.get_value())
	sprite.hide()
	timer = 0

func _process(delta: float) -> void:
	if timer < bat_data.fire_rate.get_value():
		timer += delta
		return
	timer = 0
	smash()
	

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
	if game_paused and sprite.is_playing():
		sprite.pause()
	if !game_paused and !sprite.is_playing():
		sprite.play()


func _on_fire_rate_timeout() -> void:
	smash()

func smash() -> void : 
	sprite.show()
	smash_shape.call_deferred("set_disabled",false)
	whoosh_sfx.play()
	sprite.play("slashing")


func _on_smash_zone_area_entered(area: Area2D) -> void:
	if "get_damages" in area and area.is_in_group("ennemies"):
		area.get_damages(bat_data.dmg.get_value())
		bat_data.total_damages_dealt += int(bat_data.dmg.get_value())

func _on_animation_finished() -> void:
		smash_shape.call_deferred("set_disabled",true)
