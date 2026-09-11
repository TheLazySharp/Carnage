extends Area2D
## Pooled collectable: _ready() runs once per run, activate() runs at every
## spawn. Nothing is instantiated or freed during gameplay.

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

#---- JUICE
const SPAWN_SPEED_MIN : float = 120.0
const SPAWN_SPEED_MAX : float = 260.0
const SPAWN_GRAVITY : float = 300.0
const SPAWN_DURATION : float = 0.6
const ATTRACT_SPEED : float = 500.0
const MAGNET_SPEED : float = 800.0
const COLLECT_DISTANCE_SQ : float = 25.0

var pool : CollectablePool
var pool_index : int = -1
var is_active : bool = false
var game_paused : bool = false

var xp_data : XPData
var xp_value : int
var speed : float = ATTRACT_SPEED
var is_attracted : bool = false
var can_be_collected : bool = false
var is_spawn_phase : bool = false
var spawn_velocity : Vector2 = Vector2.ZERO
var spawn_elapsed : float = 0.0
var player : CharacterBody2D


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	ItemManager.magnet_xp.connect(_on_magnet_picked_up)
	player = get_node_or_null("/root/World/Car") as CharacterBody2D


## Called once by the pool right after instantiation.
func setup_pooled(owner_pool : CollectablePool, index : int) -> void:
	pool = owner_pool
	pool_index = index
	deactivate()


func activate(spawn_position : Vector2, data : XPData) -> void:
	xp_data = data
	xp_value = TimeManager.current_day
	animated_sprite_2d.sprite_frames = pool.get_xp_frames(data)
	animated_sprite_2d.play("blooming")

	global_position = spawn_position
	var angle : float = randf_range(0.0, TAU)
	var force : float = randf_range(SPAWN_SPEED_MIN, SPAWN_SPEED_MAX)
	spawn_velocity = Vector2(cos(angle), sin(angle)) * force
	spawn_elapsed = 0.0
	is_spawn_phase = true
	is_attracted = false
	can_be_collected = false
	speed = ATTRACT_SPEED
	is_active = true

	show()
	set_physics_process(true)
	# Deferred: activate() can be reached from inside a physics callback
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)


func deactivate() -> void:
	is_active = false
	is_attracted = false
	can_be_collected = false
	is_spawn_phase = false
	hide()
	set_physics_process(false)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)


func _physics_process(delta: float) -> void:
	if game_paused or player == null:
		return

	if is_spawn_phase:
		spawn_elapsed += delta
		spawn_velocity = spawn_velocity.move_toward(Vector2.ZERO, SPAWN_GRAVITY * delta)
		global_position += spawn_velocity * delta
		if spawn_elapsed >= SPAWN_DURATION:
			is_spawn_phase = false
			can_be_collected = true
			if not is_attracted:
				# Idle on the ground: stop processing until the player comes close
				set_physics_process(false)
		return

	if not is_attracted:
		set_physics_process(false)
		return

	var to_player : Vector2 = player.global_position - global_position
	var distance_squared : float = to_player.length_squared()
	if can_be_collected and distance_squared < COLLECT_DISTANCE_SQ:
		XPManager.add_xp_in_bucket(xp_value)
		pool.release_xp(pool_index)
		return
	global_position += to_player.normalized() * speed * delta


func _on_area_entered(area: Area2D) -> void:
	if is_active and can_be_collected and area.is_in_group("player"):
		is_attracted = true
		set_physics_process(true)


func _on_magnet_picked_up() -> void:
	if not is_active:
		return
	is_attracted = true
	speed = MAGNET_SPEED
	set_physics_process(true)


func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
