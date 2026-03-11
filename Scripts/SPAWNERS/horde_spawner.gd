extends Node2D

const ENEMY = preload("uid://c31g0smlywes2")

var max_enemy_count : int = 50
var horde : Array[Enemy]
@export var is_active : bool = true

@onready var game_manager: Node = $"/root/World/game_manager"
var game_paused:=false

@onready var enemies_manager: EnemiesManager = $"/root/World/EnemiesManager"


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	if is_active:
		create_horde()
	
	
func _process(_delta: float) -> void:
	pass
	
func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause


func create_horde() -> void :
	var leader : Enemy
	for i in max_enemy_count:
		var enemy : Enemy = ENEMY.instantiate()
		add_child(enemy)
		enemies_manager.count_enemies(1)
		if i == 0: 
			enemy.is_leader = true
			leader = enemy
			set_leader(enemy)
		else : 
			enemy.is_leader = false
		enemy.activate(global_position)
		horde.append(enemy)
		enemy.horde = horde
	enemies_manager.enemies_hordes.append(horde)
	
	for i in horde.size():
		if horde[i] == leader:
			leader.leader = null
		else :
			horde[i].leader = leader

func set_leader(leader : Enemy) -> void:
	leader.scale = Vector2(2,2)
	leader.max_life = 50
	leader.damages_on_player = 5
	
