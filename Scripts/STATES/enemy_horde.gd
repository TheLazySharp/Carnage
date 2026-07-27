extends State
class_name EnemyHorde

@onready var player : CharacterBody2D = $"/root/World/Car"
@onready var flow_field: FlowFieldManager = $"/root/World/FlowFieldManager"
@onready var enemy: Enemy = self.get_parent().get_parent()

var move_direction : Vector2
var wander_time : float
var game_paused :  bool = false

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	move_direction = enemy.global_position.direction_to(player.global_position)

func enter()-> void:
	pass

func exit()-> void:
	pass 


func physics_update(_delta: float)-> void:
	if game_paused:
		return
	var direction : Vector2 = flow_field.get_flow_direction(enemy.global_position)
	enemy.velocity = direction * enemy.speed.get_value()


func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause

func _on_update_dir_timeout() -> void:
	move_direction = enemy.global_position.direction_to(player.global_position)
