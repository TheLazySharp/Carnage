extends Area2D

var dollar : DollarData
var value : int
@onready var icon: Sprite2D = $Sprite2D
var game_paused : bool = false

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
	dollar = InventoryManager.pick_dollar()
	value = dollar.value
	icon.texture = dollar.icon


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
	
	if abs(global_position - player.global_position).length() > 100 :
		is_attracted = false
	
	if can_be_collected and abs(global_position - player.global_position).length() < 5:
		InventoryManager.fortune += value
		SignalManager.emit_signal("dollar_picked_up")
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and can_be_collected:
		is_attracted = true


func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
