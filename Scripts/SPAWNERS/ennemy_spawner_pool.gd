extends Node2D

@onready var timer: Timer = $Timer

const ENEMY = preload("uid://c31g0smlywes2")

var max_enemy_count : int = 200
var enemies_pool : Array[Enemy]
var nb_active_enemies : int = 0
@onready var game_manager: Node = $"/root/World/GameManager"
var game_paused:=false

@onready var zombies_q: Label = $"../../CanvasLayer/Board/Parts/MarginContainer/HBoxContainer/Zombies/ZombiesQ"


@export var auto_spawn:= true

func _ready() -> void:
	randomize()
	create_enemies_pool(max_enemy_count)
	SignalManager.game_paused.connect(_on_game_paused)
	zombies_q.text = str(nb_active_enemies)

func _process(_delta: float) -> void:
	zombies_q.text = str(nb_active_enemies)
	
	
func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
	

func _on_timer_timeout() -> void:
	if not game_paused and auto_spawn:
		#var random_spawn_point : Node2D
		var r : int = RandomNumberGenerator.new().randi_range(0,10)
		for spawn_point in self.get_children():
			if spawn_point.name.to_int() == r and spawn_point.is_class("Marker2D"):
				pick_enemy_from_pool(Vector2(spawn_point.global_position.x,spawn_point.global_position.y))
				#print("enemy spawned on : ",spawn_point)


func pick_enemy_from_pool(starting_position: Vector2) -> void:
	get_enemy_from_pool().activate(starting_position)


func create_enemies_pool(nb_enemies: int) -> void:
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
	
func add_enemy_to_pool(enemy: Enemy) -> void:
	enemies_pool.append(enemy)
	
func activated_enemies(n : int) -> int:
	nb_active_enemies += n
	print(nb_active_enemies)
	return nb_active_enemies
	
