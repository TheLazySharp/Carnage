extends Node2D


@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var is_open:= false
var car_ok : bool
var end_day_scene:= "uid://dkpvtoel7hhai"
@onready var collision_shape: CollisionShape2D = $CollisionShape
@onready var warp_zone: Area2D = $WarpZone

@onready var day_manager: Node = $"../DayManager"
var day_ended:=false

@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:=false

signal forward_only(car_ok : bool)
signal full_command(engine_on: bool)

func _ready() -> void:
	gm_scene.game_paused.connect(_on_game_paused)
	day_manager.day_ended.connect(_on_day_ended)
	collision_shape.set_deferred("disabled",true)
	warp_zone.set_deferred("disabled",true)
	car_ok = true
	emit_signal("full_command", car_ok)
	emit_signal("forward_only", car_ok)
	

func _process(_delta: float) -> void:
	if !is_open and sprite.animation_finished:
		is_open = true
	
	if is_open and sprite.animation_finished:
		is_open = false
	
	#if is_open:
		#collision_shape.set_deferred("disabled",true)
		#warp_zone.set_deferred("disabled",false)
		#
	#else : collision_shape.set_deferred("disabled",false)

	
func _on_warp_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and day_ended:
		sprite.play("closing")
		car_ok = false
		emit_signal("full_command", car_ok)
		await get_tree().create_timer(4).timeout
		SceneManager.load_level(end_day_scene)



func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
	
func _on_day_ended(day_is_ended : bool) -> void :
	day_ended = day_is_ended
	if day_ended:
		sprite.play("opening")
		collision_shape.set_deferred("disabled",true)
		warp_zone.set_deferred("disabled",false)


func _on_exit_zone_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		sprite.play("closing")
		car_ok = false
		emit_signal("forward_only", car_ok)
		collision_shape.set_deferred("disabled",false)
