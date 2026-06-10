extends State
class_name EnemyHorde

@onready var player : CharacterBody2D = $"/root/World/Car"

@onready var enemy: Enemy = self.get_parent().get_parent()

var move_direction : Vector2
var wander_time : float
var move_speed : float
var speed_offset : float = 10

var game_paused :  bool = false

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	move_direction = enemy.global_position.direction_to(player.global_position)

func enter()-> void:
	move_speed = randf_range((enemy.enemy.speed.get_value() - speed_offset),(enemy.enemy.speed.get_value() + speed_offset))

func exit()-> void:
	pass 


func physics_update(_delta: float)-> void:
	if !game_paused:
		enemy.velocity = move_direction * move_speed


func randomize_wander()-> void:
	move_direction = Vector2(randf_range(-1,1),randf_range(-1,1)).normalized()
	wander_time = randf_range(1,3)
	move_speed = randf_range((enemy.enemy.speed.get_value() - speed_offset),(enemy.enemy.speed.get_value() + speed_offset))

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause

func _on_update_dir_timeout() -> void:
	move_direction = enemy.global_position.direction_to(player.global_position)
