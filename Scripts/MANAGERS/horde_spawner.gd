extends Node2D
const ENEMY = preload("uid://c31g0smlywes2")

var max_enemy_count : int = 100


@export var is_active:= true
@onready var game_manager: Node = $"/root/World/game_manager"
var game_paused:=false
@onready var horde_spawn_point: Marker2D = $HordeSpawnPoint


func _ready() -> void:
	randomize()
	if is_active:
		create_enemies_pool(max_enemy_count)
	game_manager.game_paused.connect(_on_game_paused)

func _on_game_paused(game_on_pause) -> void:
	game_paused = game_on_pause


func create_enemies_pool(nb_enemies: int):
	for i in nb_enemies:
		var enemy : Enemy = ENEMY.instantiate()
		get_node("/root/World/Horde").add_child(enemy)
		#enemy.apply_scale(Vector2(4,4))
		#enemy.max_life = 100
		enemy.activate(horde_spawn_point.global_position)
		print("BOSS ACTIVATED !!!!")
