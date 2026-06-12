extends Node2D

const ENEMY = preload("uid://c31g0smlywes2")

@export var is_active : bool = true
@export var enemy_type : EnemyManager.Enemy_Types
var renderer : EnemiesMultiMeshRenderer

var max_enemy_count : int = 200
var nb_active_enemies : int = 0
var game_paused : bool = false
@onready var spawn_rate: Timer = $SpawnRate
@export var auto_spawn : bool = false


func _ready() -> void:
	randomize()
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.half_time.connect(_on_half_time)
	
func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
	

func create_enemies() -> Enemy:
	var resource : EnemyData = EnemyManager.Enemy_ressources[enemy_type]
	var enemy : Enemy = ENEMY.instantiate()
	enemy.enemy = resource
	enemy.renderer = renderer
	get_node("/root/World/Enemies").add_child(enemy)
	activated_enemies(1)
	enemy.state_machine.state_transition_to("horde")
	return enemy

#COUNTER
func activated_enemies(n : int) -> int:
	nb_active_enemies += n
	return nb_active_enemies
	
func _on_half_time() -> void : 
	auto_spawn = true
	spawn_rate.start()


func _on_spawn_rate_timeout() -> void:
	if not game_paused and auto_spawn and nb_active_enemies < max_enemy_count:
		var r : int = RandomNumberGenerator.new().randi_range(0,get_node("SpawnPoints").get_child_count(false))
		for spawn_point in get_node("SpawnPoints").get_children():
			if spawn_point.name.to_int() == r and spawn_point.is_class("Marker2D"):
				if spawn_point.visible:
					#print(r)
					var enemy : Enemy = create_enemies()
					enemy.activate(spawn_point.global_position)
					#print("enemy spawned on : ",spawn_point)
				else : print("spawn point visible on screen")
