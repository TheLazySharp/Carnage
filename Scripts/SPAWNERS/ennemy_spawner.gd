extends Spawner


const ENEMY = preload("uid://c31g0smlywes2")

@export var is_active : bool = true
@export var is_infinite : bool = true
@export var enemy_type : EnemyManager.Enemy_Types
var renderer : EnemiesMultiMeshRenderer
@export var max_enemy_count : int = 10

var nb_active_enemies : int = 0
var game_paused : bool = false
@onready var spawn_timer: Timer = $SpawnRate
@export var auto_spawn : bool = false


func setup_trigger() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.half_time.connect(_on_half_time)
	if auto_spawn:
		spawn_timer.wait_time = spawn_rate
		spawn_timer.start()

func configure_instance(instance : Node, _world_pos : Vector2) -> void:
	var enemy : Enemy = instance
	enemy.enemy = EnemyManager.Enemy_ressources[enemy_type]

func on_spawned(instance : Node) -> void:
	var enemy : Enemy = instance
	activated_enemies(1)
	enemy.state_machine.state_transition_to("chase")
	enemy.activate(enemy.global_position)



#COUNTER
func activated_enemies(n : int) -> int:
	nb_active_enemies += n
	return nb_active_enemies
	

func _on_spawn_rate_timeout() -> void:
	if game_paused or !auto_spawn:
		return
	if !is_infinite and nb_active_enemies >= max_enemy_count:
		spawn_timer.stop()
		return
	spawn()


func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
	if game_on_pause:
		spawn_timer.paused = true
	else : 
		spawn_timer.paused = false
	
func _on_half_time() -> void : 
	auto_spawn = true
	spawn_timer.start()
