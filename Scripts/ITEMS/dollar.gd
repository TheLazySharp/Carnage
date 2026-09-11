extends Area2D
## Pooled collectable, same pattern as the XP orb.

@onready var icon: Sprite2D = $Sprite2D

#---- JUICE
const SPAWN_SPEED_MIN : float = 200.0
const SPAWN_SPEED_MAX : float = 400.0
const SPAWN_GRAVITY : float = 400.0
const SPAWN_DURATION : float = 0.6
const ATTRACT_SPEED : float = 500.0
const MAGNET_SPEED : float = 800.0
const COLLECT_DISTANCE_SQ : float = 25.0

var pool : CollectablePool
var pool_index : int = -1
var is_active : bool = false
var game_paused : bool = false

var dollar : DollarData
var value : int
var speed : float = ATTRACT_SPEED
var is_attracted : bool = false
var can_be_collected : bool = false
var is_spawn_phase : bool = false
var is_bank_spawn_phase : bool = false
var spawn_velocity : Vector2 = Vector2.ZERO
var spawn_origin : Vector2
var landing_pos : Vector2
var spawn_elapsed : float = 0.0
var player : CharacterBody2D


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	ItemManager.wallet.connect(_on_wallet_picked_up)
	player = get_node_or_null("/root/World/Car") as CharacterBody2D


func setup_pooled(owner_pool : CollectablePool, index : int) -> void:
	pool = owner_pool
	pool_index = index
	deactivate()


func activate(spawn_position : Vector2) -> void:
	_pick_content()
	global_position = spawn_position
	var angle : float = randf_range(0.0, TAU)
	var force : float = randf_range(SPAWN_SPEED_MIN, SPAWN_SPEED_MAX)
	spawn_velocity = Vector2(cos(angle), sin(angle)) * force
	spawn_elapsed = 0.0
	is_spawn_phase = true
	is_bank_spawn_phase = false
	_start()


## Kept under its original name and signature so building.gd needs no change.
## Works both pooled and standalone: a building-spawned dollar has pool == null.
func building_launch_spawn(origin : Vector2, landing : Vector2, _spawn_item_res : ItemData = null) -> void:
	_pick_content()
	spawn_origin = origin
	landing_pos = landing
	global_position = origin
	spawn_elapsed = 0.0
	is_spawn_phase = false
	is_bank_spawn_phase = true
	_start()


func deactivate() -> void:
	is_active = false
	is_attracted = false
	can_be_collected = false
	is_spawn_phase = false
	is_bank_spawn_phase = false
	hide()
	set_physics_process(false)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)


## Was in _ready(): the pool only builds the node once, so the content must be
## drawn at every spawn instead.
func _pick_content() -> void:
	dollar = InventoryManager.pick_dollar()
	value = dollar.value
	icon.texture = dollar.icon


func _start() -> void:
	is_attracted = false
	can_be_collected = false
	speed = ATTRACT_SPEED
	is_active = true
	show()
	set_physics_process(true)
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)


func _physics_process(delta: float) -> void:
	if game_paused or player == null:
		return

	if is_spawn_phase:
		spawn_elapsed += delta
		spawn_velocity = spawn_velocity.move_toward(Vector2.ZERO, SPAWN_GRAVITY * delta)
		global_position += spawn_velocity * delta
		if spawn_elapsed >= SPAWN_DURATION:
			_on_spawn_ended()
		return

	if is_bank_spawn_phase:
		spawn_elapsed += delta
		var t : float = clampf(spawn_elapsed / SPAWN_DURATION, 0.0, 1.0)
		var ease_t : float = 1.0 - pow(1.0 - t, 3.0)
		global_position = spawn_origin.lerp(landing_pos, ease_t)
		if t >= 1.0:
			_on_spawn_ended()
		return

	if not is_attracted:
		set_physics_process(false)
		return

	var to_player : Vector2 = player.global_position - global_position
	var distance_squared : float = to_player.length_squared()
	if can_be_collected and distance_squared < COLLECT_DISTANCE_SQ:
		InventoryManager.fortune += value
		SignalManager.emit_signal("dollar_picked_up")
		if pool != null:
			pool.release_dollar(pool_index)
		else:
			queue_free()  # building-spawned: never came from the pool
		return
	global_position += to_player.normalized() * speed * delta


func _on_spawn_ended() -> void:
	is_spawn_phase = false
	is_bank_spawn_phase = false
	can_be_collected = true
	if not is_attracted:
		set_physics_process(false)


func _on_area_entered(area: Area2D) -> void:
	if is_active and can_be_collected and area.is_in_group("player"):
		is_attracted = true
		set_physics_process(true)


func _on_wallet_picked_up() -> void:
	if not is_active:
		return
	is_attracted = true
	speed = MAGNET_SPEED
	set_physics_process(true)


func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
