extends Node2D

@export var car_sprite: Node2D

@export_group("Réglages de l'effet")
@export var spawn_interval: float = 0.045
@export var afterimage_lifetime: float = 0.28
@export var min_speed_to_trigger: float = 8.0

@export var tint_gradient: Gradient
@export var tint_strength: float = 0.55        
@export_range(0.0, 1.0) var effect_alpha: float = 1.0  


const AFTERIMAGE_SHADER: Shader = preload("res://Assets/Léonce/Scripts/afterimage_shader.gdshader")

var _last_position: Vector2
var _spawn_timer: float = 0.0
var _car: Node2D


func _ready() -> void:
	_car = get_parent() as Node2D
	if car_sprite == null and _car != null:
		if _car is AnimatedSprite2D or _car is Sprite2D:
			car_sprite = _car
		else:
			car_sprite = _car.get_node_or_null("AnimatedSprite2D")
			if car_sprite == null:
				car_sprite = _car.get_node_or_null("Sprite2D")
	if _car != null:
		_last_position = _car.global_position
	if tint_gradient == null:
		tint_gradient = Gradient.new()
		tint_gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		tint_gradient.colors = PackedColorArray([
			Color(1.0, 0.85, 0.3), Color(1.0, 0.3, 0.4), Color(0.3, 0.3, 0.9)
		])


func _process(delta: float) -> void:
	if _car == null or car_sprite == null or delta <= 0.0:
		return

	var speed := _car.global_position.distance_to(_last_position) / delta
	_last_position = _car.global_position

	if speed >= min_speed_to_trigger:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = spawn_interval
			_spawn_afterimage()
	else:
		_spawn_timer = 0.0


func _spawn_afterimage() -> void:
	var tex := _get_current_texture()
	if tex == null:
		return

	var ghost := Sprite2D.new()
	ghost.texture = tex
	ghost.global_transform = car_sprite.global_transform
	ghost.z_index = car_sprite.z_index - 1

	if "flip_h" in car_sprite:
		ghost.flip_h = car_sprite.flip_h
	if "flip_v" in car_sprite:
		ghost.flip_v = car_sprite.flip_v

	var mat := ShaderMaterial.new()
	mat.shader = AFTERIMAGE_SHADER
	mat.set_shader_parameter("tint_color", tint_gradient.sample(0.0))
	mat.set_shader_parameter("tint_strength", tint_strength)
	mat.set_shader_parameter("alpha", effect_alpha)
	mat.set_shader_parameter("fade", 1.0)
	ghost.material = mat

	_car.get_parent().add_child(ghost)

	var tween := ghost.create_tween()
	tween.tween_method(
		func(t: float) -> void:
			mat.set_shader_parameter("fade", 1.0 - t)
			mat.set_shader_parameter("tint_color", tint_gradient.sample(t)),
		0.0, 1.0, afterimage_lifetime
	)
	tween.finished.connect(ghost.queue_free)


func _get_current_texture() -> Texture2D:
	if car_sprite is AnimatedSprite2D:
		var a := car_sprite as AnimatedSprite2D
		if a.sprite_frames and a.animation != &"":
			return a.sprite_frames.get_frame_texture(a.animation, a.frame)
	elif car_sprite is Sprite2D:
		return (car_sprite as Sprite2D).texture
	return null
