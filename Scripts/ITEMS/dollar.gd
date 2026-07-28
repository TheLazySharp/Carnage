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
const SPAWN_SPEED_MIN : float = 200.0
const SPAWN_PEED_MAX : float = 400.0
const SPAWN_GRAVITY : float = 400.0
const SPAWN_DURATION : float = 0.6

var spawn_velocity : Vector2 = Vector2.ZERO
var is_spawn_phase : bool = false
var is_bank_spawn_phase : bool = false

var spawn_origin : Vector2
var landing_pos : Vector2
var spawn_elapsed : float = 0.0

@onready var player: CharacterBody2D = $"/root/World/Car"


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	ItemManager.wallet.connect(_on_wallet_picked_up)
	dollar = InventoryManager.pick_dollar()
	value = dollar.value
	icon.texture = dollar.icon


func launch_spawn(spawn_position : Vector2) -> void : 
	is_spawn_phase = true
	self.global_position = spawn_position
	var angle : float = randf_range(0.0, TAU)
	var force : float = randf_range(SPAWN_SPEED_MIN,SPAWN_PEED_MAX)
	spawn_velocity = Vector2(cos(angle),sin(angle)) * force
	
	var timer : SceneTreeTimer = get_tree().create_timer(SPAWN_DURATION)
	timer.timeout.connect(_on_spawn_ended)
	
func bank_launch_spawn(origin : Vector2, landing : Vector2) -> void:
	spawn_origin = origin
	landing_pos = landing
	global_position = origin
	is_bank_spawn_phase = true
	spawn_elapsed = 0.0


func _on_spawn_ended() -> void : 
	is_spawn_phase = false
	is_bank_spawn_phase = false
	can_be_collected = true

func _physics_process(delta: float) -> void:
	if game_paused :
		return
	
	if is_spawn_phase:
		spawn_velocity = spawn_velocity.move_toward(Vector2.ZERO, SPAWN_GRAVITY * delta)
		global_position += spawn_velocity * delta
		return

	if is_bank_spawn_phase:
		spawn_elapsed += delta
		var t : float = clampf(spawn_elapsed / SPAWN_DURATION, 0.0, 1.0)
		var ease_t : float = 1.0 - pow(1.0 - t, 3.0)
		global_position = spawn_origin.lerp(landing_pos, ease_t)
		# arc optionnel : global_position.y -= sin(t * PI) * 24.0
		if t >= 1.0:
			_on_spawn_ended()
		return

	if is_attracted:
		target_pos = player.global_position
		var dir : Vector2 = self.global_position.direction_to(target_pos)
		velocity = dir.normalized() * speed
		global_position += velocity * delta
	
	if abs(global_position - player.global_position).length() > 150 and !can_be_collected:
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
	
func _on_wallet_picked_up() -> void : 
	is_attracted = true
	speed = 800
