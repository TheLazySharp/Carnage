extends Node2D

@onready var timer: Timer = $Timer

const ENEMY = preload("uid://c31g0smlywes2")

var max_enemy_count : int = 100
var enemies_pool : Array[Enemy]

@onready var game_manager: Node = $"/root/World/game_manager"
var game_paused:=false


@export var auto_spawn:= true

func _ready() -> void:
	randomize()
	create_enemies_pool(max_enemy_count)
	game_manager.game_paused.connect(_on_game_paused)

func _on_game_paused(game_on_pause) -> void:
	game_paused = game_on_pause
	

func _on_timer_timeout() -> void:
	if not game_paused and auto_spawn:
		#var random_spawn_point : Node2D
		var r = RandomNumberGenerator.new().randi_range(0,10)
		for spawn_point in self.get_children():
			if spawn_point.name.to_int() == r and spawn_point.is_class("Marker2D"):
				pick_enemy_from_pool(Vector2(spawn_point.global_position.x,spawn_point.global_position.y))
				#print("enemy spawned on : ",spawn_point)


func pick_enemy_from_pool(starting_position: Vector2) -> void:
	get_enemy_from_pool().activate(starting_position)


func create_enemies_pool(nb_enemies: int):
	for i in nb_enemies:
		var enemy : Enemy = ENEMY.instantiate()
		enemy.desactivate()
		get_node("/root/World/Enemies").add_child(enemy)
		enemies_pool.append(enemy)
	#print(enemies_pool.size(), " Enemies have been pooled")


func get_enemy_from_pool() -> Enemy:
	var enemy : Enemy
	if enemies_pool.is_empty():
		#print("enemy pool is empty")
		create_enemies_pool(1)
		enemy = enemies_pool[0]
	else:
		enemy = enemies_pool[0]
		enemies_pool.remove_at(0)
	return enemy
	
func add_enemy_to_pool(enemy: Enemy):
	enemies_pool.append(enemy)
	
