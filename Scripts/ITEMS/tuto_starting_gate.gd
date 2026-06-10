extends Node2D


@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var is_open:= false
var car_ok : bool
@onready var collision_shape: CollisionShape2D = $CollisionShape
@onready var warp_zone: Area2D = $WarpZone

@onready var tuto_scene: Node2D = $".."



var game_paused:=false

signal forward_only(car_ok : bool)
signal full_command(engine_on: bool)


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	tuto_scene.tuto_end.connect(_on_tuto_ended)
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
	

	
func _on_warp_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if !SceneManager.tuto_completed:
			SceneManager.tuto_completed = true
		body.global_position = self.global_position
		WeaponsManager.activate_weapons(false)
		sprite.play("closing")
		car_ok = false
		emit_signal("full_command", car_ok)
		await get_tree().create_timer(3).timeout
		SceneManager.load_level(SceneManager.SCENES.MAIN_MENU)



func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
	
func _on_tuto_ended() -> void:
	sprite.play("opening")
	collision_shape.set_deferred("disabled",true)
	warp_zone.set_deferred("disabled",false)


func _on_exit_zone_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		if !WeaponsManager.weapons.is_empty():
			for i in WeaponsManager.weapons.size():
				WeaponsManager.weapons[i].weapon_is_active = true
		sprite.play("closing")
		car_ok = false
		emit_signal("forward_only", car_ok)
		collision_shape.set_deferred("disabled",false)
