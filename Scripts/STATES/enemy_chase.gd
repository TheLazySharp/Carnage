extends State
class_name EnemyChase

@onready var enemy: Enemy = $"../.."
@onready var target: Node2D = $"/root/World/Car"
@onready var navigation_agent: NavigationAgent2D = $"../../NavigationAgent2D"

var nav_point_direction: Vector2
#var move_speed: float
var chase_speed_boost: float = 1.6


var game_paused: bool =false
var game_over : bool = false

#HORDE SETTINGS : FLOCKING
var attraction_to_leader : float = 2
var repulsion_weight : float = 3
#var cohesion_weight : float = 0.1
var repulsion_radius : float = 10
var repulsion_radius_sq : float

#var cohesion_radius : float = 30
var formation_offset : Vector2
var forces_timer : float = 0
var forces_timer_steps : float
var leader_nav_timer : float = 0
var leader_nav_steps : float = 0.4

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.game_is_over.connect(_on_game_over)
	forces_timer_steps = randf_range(0.5,0.8)
	repulsion_radius_sq = repulsion_radius * repulsion_radius

func enter() -> void:
	if game_over :
		state_changed.emit(self,"idle")
		return
	if !enemy.is_leader:
		pass
		#enemy.set_enemy_color(Color.GREEN_YELLOW)
	
	navigation_agent.target_position = target.global_position
	#move_speed = 
	
	var angle : float = randf() * TAU
	var dist : float = randf_range(10,50)
	formation_offset = Vector2(cos(angle),sin(angle)) * dist
	
	#enemy.set_enemy_color(Color.GREEN)

func exit()-> void:
	pass


#func update(_delta : float)-> void:
	#pass


func physics_update(delta: float)-> void:
	forces_timer -= delta
	leader_nav_timer += delta
	
	if leader_nav_timer >= get_nav_steps() and enemy.is_leader:
		leader_nav_timer = 0
		leader_behavior(delta)
	
	if forces_timer <= 0 and ! enemy.is_leader:
		forces_timer = forces_timer_steps
		trouper_behavior(delta)



func get_nav_steps() -> float:
	var dist_sq : float = enemy.global_position.distance_squared_to(target.global_position)
	if dist_sq < 100 * 100:
		return 0.2
	if dist_sq < 500 * 500:
		return 0.35
	else :
		return 0.5

func _on_game_over(game_is_over : bool)-> void : 
	game_over = game_is_over
	if game_is_over :
		state_changed.emit(self,"idle") 

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause

func _on_navigation_agent_2d_target_reached() -> void:
	pass
	#print("target reached")
	#state_changed.emit(self,"attack")


func leader_behavior(_delta : float) -> void:
	if !enemy.is_leader:
		return
	if !game_paused:
		navigation_agent.target_position = target.global_position
		var next_pos: Vector2 = navigation_agent.get_next_path_position()
		var dir: Vector2 = (next_pos - enemy.global_position)
		if dir.length_squared() > 1:
			enemy.velocity = dir.normalized() * enemy.enemy.speed.get_value() * chase_speed_boost
		else : 
			enemy.velocity = Vector2.ZERO
		#enemy.sprite_update(next_pos)


func trouper_behavior(_delta : float) -> void:
	if enemy.leader == null or enemy.is_leader:
		return

	var target_position : Vector2 = enemy.leader.global_position + formation_offset
	var to_target : Vector2 = target_position - enemy.global_position
	var dist_to_target_sq : float = to_target.length_squared()
	
	if dist_to_target_sq < 100 :
		enemy.velocity = Vector2.ZERO
		return
	
	var attraction_force : Vector2 = Vector2.ZERO
	var repulsion_force : Vector2 = Vector2.ZERO
	
	#var cohesion_force := Vector2.ZERO
	#var troupers_count: int = 0
	#var center_of_horde := Vector2.ZERO
	
	#-------------------- Attraction toward leader / only if trouper is far from leader ---------------
	
	if dist_to_target_sq > 25:
		attraction_force = to_target.normalized() * attraction_to_leader


	#-------------------- floaking : enemy repuslion to each others and global cohesion of the horde ----------------------
	
	for i in range(enemy.horde_neighbors.size() -1,-1,-1):
		if enemy.horde_neighbors[i] == enemy or !is_instance_valid(enemy.horde_neighbors[i]):
			continue
		var diff_dist : Vector2 = (enemy.global_position - enemy.horde_neighbors[i].global_position)
		var dist_sq : float = diff_dist.length_squared()
		
		if dist_sq < repulsion_radius_sq and dist_sq > 0.0001:
			#repulsion_force += diff_dist.normalized() * ( repulsion_radius_sq /dist_sq) * repulsion_weight
			var overlap_ratio: float = repulsion_radius_sq / max(dist_sq, 1.0)
			repulsion_force += diff_dist.normalized() * overlap_ratio
			
		#if dist_sq < 400 and dist_sq > 0.0001:
			#var min_strenght : float = clamp(400 / dist_sq,1,5)
			#repulsion_force += diff_dist.normalized() * min_strenght * repulsion_weight
			
		#if dist_cohesion < cohesion_radius:
			#center_of_horde += enemy.horde_neighbors[i].global_position
			#troupers_count += 1
	
	#if repulsion_force.length_squared() > 0.0001:
		#repulsion_force = repulsion_force.normalized() * repulsion_weight
	
			
	#if troupers_count > 0:
		#center_of_horde /= troupers_count
		#var to_center: Vector2 = (center_of_horde - enemy.global_position)
		#if to_center.length() > 0.01:
			#cohesion_force = to_center.normalized() * cohesion_weight
		

	
	#------------------------ GLOBAL BEHAVIOUR --------------------
	#var total_forces : Vector2 = attraction_force + repulsion_force + cohesion_force
	var total_forces : Vector2 = attraction_force + repulsion_force
	
	if total_forces.length_squared() > 0.0001:
		enemy.velocity = total_forces.normalized() * enemy.enemy.speed.get_value() * chase_speed_boost
	else : 
		enemy.velocity = Vector2.ZERO
