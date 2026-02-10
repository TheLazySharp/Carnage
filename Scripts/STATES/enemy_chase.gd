extends State
class_name EnemyChase

@onready var enemy: Enemy = $"../.."
@onready var target: Node2D = $"/root/World/Car"
@onready var navigation_agent: NavigationAgent2D = $"../../NavigationAgent2D"

var nav_point_direction: Vector2
var move_speed: float
var chase_speed_boost: float = 1.3

@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:=false

func _ready() -> void:
	gm_scene.game_paused.connect(_on_game_paused)

func enter() -> void:
	#print("entering chase")
	navigation_agent.target_position = target.global_position
	move_speed = enemy.speed * chase_speed_boost
	SignalManager.emit_signal("enemy_chasing",enemy)

func exit()-> void:
	SignalManager.emit_signal("enemy_exiting_chase", enemy)


func update(_delta : float)-> void:
	pass
			

func update_dir(updated_dir : Vector2) ->void:
	nav_point_direction = updated_dir

func physics_update(_delta: float)-> void:
	if game_paused : return
	var next_pos: Vector2 = navigation_agent.get_next_path_position()
	var dir: Vector2 = (next_pos - enemy.global_position).normalized()
	enemy.velocity = dir * move_speed
	

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause

func _on_navigation_agent_2d_target_reached() -> void:
	#print("target reached")
	state_changed.emit(self,"attack")
	
