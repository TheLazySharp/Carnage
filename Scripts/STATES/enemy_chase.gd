extends State
class_name EnemyChase

@onready var enemy: Enemy = $"../.."
@onready var target: Node2D = $"/root/World/Car"
@onready var navigation_agent: NavigationAgent2D = $"../../NavigationAgent2D"
@onready var path_timer: Timer = $"../../PathTimer"


var nav_point_direction: Vector2
var move_speed: float
var chase_speed_boost: float = 1.2

@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:=false

func _ready() -> void:
	gm_scene.game_paused.connect(_on_game_paused)

func enter() -> void:
	navigation_agent.target_position = target.global_position
	path_timer.start()
	move_speed = enemy.speed * chase_speed_boost

func exit()-> void:
	pass


func update(_delta: float)-> void:
	if not game_paused:
		if not navigation_agent.is_target_reached():
			nav_point_direction = enemy.to_local(navigation_agent.get_next_path_position()).normalized()
			

func physics_update(_delta: float)-> void:
	enemy.velocity = nav_point_direction * move_speed

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause


func _on_path_timer_timeout() -> void:
	if navigation_agent.target_position != target.global_position:
		navigation_agent.target_position = target.global_position
	path_timer.start()
