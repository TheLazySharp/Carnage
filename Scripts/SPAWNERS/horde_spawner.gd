extends Node2D

const ENEMY = preload("uid://c31g0smlywes2")

@export var is_active : bool = true
@export var enemy_type : EnemyManager.Enemy_Types

var renderer : EnemiesMultiMeshRenderer

var max_enemy_count : int
var horde : Array[Enemy]

var game_paused : bool = false

@onready var horde_manager: HordeManager = $"/root/World/HordesManager"

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	max_enemy_count = 20 if GameMaster.game_mode == GameMaster.GAME_MODES.GOD else 20

	if is_active:
		create_horde()

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause


func create_horde() -> void :
	var resource : EnemyData = EnemyManager.Enemy_ressources[enemy_type]
	
	var leader : Enemy
	for i in max_enemy_count:
		var enemy : Enemy = ENEMY.instantiate()
		enemy.enemy = resource
		enemy.renderer = renderer
		add_child(enemy)
		horde_manager.count_enemies(1)
		if i == 0: 
			enemy.is_leader = true
			leader = enemy
			set_leader(enemy)
		else : 
			enemy.is_leader = false
		enemy.activate(global_position)
		horde.append(enemy)
		enemy.horde = horde
	horde_manager.enemies_hordes.append(horde)
	
	for i in horde.size():
		if horde[i] == leader:
			leader.leader = null
		else :
			horde[i].leader = leader
	#print(horde_manager.total_enemies)

func set_leader(_leader : Enemy) -> void:
	#leader.set_enemy_color(Color.BLACK)
	#leader.max_life = 2
	#leader.damages_on_player = 5
	pass
	
