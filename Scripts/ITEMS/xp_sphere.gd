extends Area2D

var game_paused : bool = false

@export var xp_data : XPData
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


var velocity: Vector2
var target_pos: Vector2
var speed : = 500
var is_attracted : bool = false
var xp_value : int
var can_be_collected : bool = false

#---- JUICE
const SPAWN_SPEED_MIN : float = 120.0
const SPAWN_PEED_MAX : float = 260.0
const SPAWN_GRAVITY : float = 300.0
const SPAWN_DURATION : float = 0.6

var spawn_velocity : Vector2 = Vector2.ZERO
var is_spawn_phase : bool = true

@onready var player: CharacterBody2D = $"/root/World/Car"


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	xp_value = TimeManager.current_day
	setup_animation()

func launch_spawn(spawn_position : Vector2) -> void : 
	self.global_position = spawn_position
	var angle : float = randf_range(0.0, TAU)
	var force : float = randf_range(SPAWN_SPEED_MIN,SPAWN_PEED_MAX)
	spawn_velocity = Vector2(cos(angle),sin(angle)) * force
	
	var timer : SceneTreeTimer = get_tree().create_timer(SPAWN_DURATION)
	timer.timeout.connect(_on_spawn_ended)
	

func _on_spawn_ended() -> void : 
	is_spawn_phase = false
	can_be_collected = true

func _physics_process(delta: float) -> void:
	if game_paused :
		return
	
	if is_spawn_phase:
		spawn_velocity = spawn_velocity.move_toward(Vector2.ZERO, SPAWN_GRAVITY * delta)
		global_position += spawn_velocity * delta
		return
	
	if is_attracted:
		target_pos = player.global_position
		var dir : Vector2 = self.global_position.direction_to(target_pos)
		velocity = dir.normalized() * speed
		global_position += velocity * delta
	
	if abs(global_position - player.global_position).length() > 150 :
		is_attracted = false
	
	if can_be_collected and abs(global_position - player.global_position).length() < 5:
		XPManager.add_xp_in_bucket(xp_value)
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player") and can_be_collected:
		is_attracted = true

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause

func setup_animation()-> void : 
	var sprite_frames : SpriteFrames = SpriteFrames.new()
	sprite_frames.add_animation("blooming")
	sprite_frames.set_animation_loop("blooming",true)
	sprite_frames.set_animation_speed("blooming",xp_data.fps)
	
	var texture : Texture2D = xp_data.spritesheet
	@warning_ignore("integer_division")
	var frames_width : int = texture.get_width() / xp_data.hframes
	@warning_ignore("integer_division")
	var frames_height : int = texture.get_height() / xp_data.vframes
	
	for i in xp_data.hframes:
		var atlas : AtlasTexture = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * frames_width,xp_data.row * frames_height,frames_width,frames_height)
		sprite_frames.add_frame("blooming",atlas)
		
	animated_sprite_2d.sprite_frames = sprite_frames
	animated_sprite_2d.play("blooming")
