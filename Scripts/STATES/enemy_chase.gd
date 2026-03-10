extends State
class_name EnemyChase

@onready var enemy: Enemy = $"../.."
@onready var target: Node2D = $"/root/World/Car"
@onready var navigation_agent: NavigationAgent2D = $"../../NavigationAgent2D"

var nav_point_direction: Vector2
var move_speed: float
var chase_speed_boost: float = 1.6


var game_paused:=false

#HORDE SETTINGS : FLOCKING
var attraction_to_leader : float = 1.5
var repulsion_weight : float = 1.5
var cohesion_weight : float = 0.5
var repulsion_radius : float = 20
var cohesion_radius : float = 80
var formation_offset : Vector2
var forces_timer : float = 0
var forces_timer_steps : float


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	forces_timer_steps = randf_range(0.5,0.8)

func enter() -> void:
	$"../../AnimatedSprite2D".self_modulate = Color.GREEN_YELLOW
	
	navigation_agent.target_position = target.global_position
	move_speed = enemy.speed * chase_speed_boost
	SignalManager.emit_signal("enemy_chasing",enemy)

func exit()-> void:
	SignalManager.emit_signal("enemy_exiting_chase", enemy)


func update(_delta : float)-> void:
	pass

#func update_dir(updated_dir : Vector2) ->void:
	#nav_point_direction = updated_dir

func physics_update(delta: float)-> void:
	forces_timer -= delta
	

	if forces_timer <= 0:
		if enemy.is_leader:
			forces_timer = forces_timer_steps
			leader_behavior(delta)
			enemy.sprite_update(target.global_position)
		else:
			forces_timer = forces_timer_steps
			trouper_behavior(delta)
			enemy.sprite_update(target.global_position)
	

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause

func _on_navigation_agent_2d_target_reached() -> void:
	#print("target reached")
	state_changed.emit(self,"attack")


func leader_behavior(_delta : float) -> void:
	if !game_paused:
		navigation_agent.target_position = target.global_position
		var next_pos: Vector2 = navigation_agent.get_next_path_position()
		var dir: Vector2 = (next_pos - enemy.global_position)
		
		if dir.length() > 1:
			enemy.velocity = dir.normalized() * move_speed
		else : 
			enemy.velocity = Vector2.ZERO
			


func trouper_behavior(_delta : float) -> void:
	if enemy.leader == null:
		return
	
	#-------------------- Attraction toward leader / only if trouper is far from leader ---------------
	var target_position : Vector2 = enemy.leader.global_position + formation_offset
	var to_target : Vector2 = target_position - enemy.global_position
	var attraction_force : Vector2 = Vector2.ZERO
	
	if to_target.length() > 5:
		attraction_force = to_target.normalized() * attraction_to_leader
	
	#-------------------- repulsion from other trouper -----------------------
	var repulsion_force : Vector2 = Vector2.ZERO
	
	#if !enemy.horde.is_empty():
	for i in range(enemy.horde.size() -1,-1,-1):
		if enemy.horde[i] == enemy or !is_instance_valid(enemy.horde[i]):
			continue
		var diff_dist : Vector2 = (enemy.global_position - enemy.horde[i].global_position)
		var dist : float = diff_dist.length()
		if dist < repulsion_radius and dist > 0.01:
			repulsion_force += diff_dist.normalized() /dist
	
	if repulsion_force.length() > 0.01:
		repulsion_force = repulsion_force.normalized() * repulsion_weight
		
	
	#------------------ horde cohesion --------------------
	var cohesion_force := Vector2.ZERO
	var troupers_count: int = 0
	var center_of_horde := Vector2.ZERO
	
	#if !enemy.horde.is_empty():
	for i in range(enemy.horde_neighbors.size() -1,-1,-1):
		if enemy.horde_neighbors[i] == enemy or !is_instance_valid(enemy.horde_neighbors[i]):
			continue
		var dist : float = enemy.global_position.distance_to(enemy.horde_neighbors[i].global_position)
			
		if dist < cohesion_radius:
			center_of_horde += enemy.horde_neighbors[i].global_position
			troupers_count += 1
			
			if troupers_count > 0:
				center_of_horde /= troupers_count
				var to_center: Vector2 = (center_of_horde - enemy.global_position)
				if to_center.length() > 0.01:
					cohesion_force = to_center.normalized() * cohesion_weight
	
	#------------------------ GLOBAL BEHAVIOUR --------------------
	var total_forces : Vector2 = attraction_force + repulsion_force + cohesion_force
	
	if total_forces.length() > 0.01:
		enemy.velocity = total_forces.normalized() * move_speed
	else : 
		enemy.velocity = Vector2.ZERO
