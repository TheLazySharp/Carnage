extends State
class_name EnemyIdle

@onready var enemy: Enemy = self.get_parent().get_parent()

var wander_target : Vector2
var wander_time : float
var move_speed: float
var speed_offset : int = 10

#HORDE SETTINGS : FLOCKING
var attraction_to_leader : float = 2
var repulsion_weight : float = 2
var cohesion_weight : float = 0.3
var repulsion_radius : float = 20
var cohesion_radius : float = 50
var formation_offset : Vector2
var forces_timer : float = 0
var forces_timer_steps : float
var leader_dest : Vector2

var game_paused:=false

@onready var day_manager: Node = $/root/World/DayManager
var day_is_ended : bool = false


func _ready() -> void:
	forces_timer_steps = randf_range(0.5,0.8)
	SignalManager.game_paused.connect(_on_game_paused)
	day_manager.day_ended.connect(_on_day_end)


func enter()-> void:
	init_formation()
	move_speed = (enemy.speed + speed_offset)


func init_formation()-> void:
	var angle : float = randf() * TAU
	var radius : float = randf_range(30,80)
	formation_offset = Vector2(cos(angle),sin(angle)) * radius



func exit()-> void:
	pass
	
func update(_delta : float)-> void:
	pass


func physics_update(delta: float)-> void:
	forces_timer -= delta

	if forces_timer <= 0:
		leader_behavior(delta)

		if !enemy.is_leader:
			forces_timer = forces_timer_steps
			trouper_behavior(delta)



func leader_behavior(delta : float) -> void:
	if !enemy.is_leader:
		return
	if !game_paused:
		wander_time -= delta
		if wander_time <= 0: 
			wander_time = randf_range(1,3)
			var angle : float = randf() * TAU
			var dist : float = randf_range(30,200)
			wander_target = enemy.global_position + Vector2(cos(angle),sin(angle)) * dist
		
		var wander_direction : Vector2 = (wander_target - enemy.global_position)
		if wander_direction.length() > 5:
			enemy.velocity = wander_direction.normalized() * move_speed
		else : 
			enemy.velocity = Vector2.ZERO
		leader_dest = wander_target
		enemy.sprite_update(wander_target)


func trouper_behavior(_delta : float) -> void:
	if enemy.leader == null or enemy.is_leader:
		return
	
	#-------------------- Attraction toward leader / only if trouper is far from leader ---------------
	var target_position : Vector2 = enemy.leader.global_position + formation_offset
	var to_target : Vector2 = target_position - enemy.global_position
	var attraction_force : Vector2 = Vector2.ZERO
	var repulsion_force : Vector2 = Vector2.ZERO
	var cohesion_force := Vector2.ZERO
	var troupers_count: int = 0
	var center_of_horde := Vector2.ZERO
	
	if to_target.length() > 5:
		attraction_force = to_target.normalized() * attraction_to_leader
	
	enemy.sprite_update(target_position)
	
	#-------------------- floaking : enemy repuslion to each others and global cohesion of the horde ----------------------

	for i in range(enemy.horde_neighbors.size() -1,-1,-1):
		if enemy.horde_neighbors[i] == enemy or !is_instance_valid(enemy.horde_neighbors[i]):
			continue
		var diff_dist : Vector2 = (enemy.global_position - enemy.horde_neighbors[i].global_position)
		var dist : float = diff_dist.length()
		
		if dist < repulsion_radius and dist > 0.01:
			repulsion_force += diff_dist.normalized() /dist
	
		var dist_cohesion : float = enemy.global_position.distance_to(enemy.horde_neighbors[i].global_position)
			
		if dist_cohesion < cohesion_radius:
			center_of_horde += enemy.horde_neighbors[i].global_position
			troupers_count += 1
	
	
	if repulsion_force.length_squared() > 0.0001:
		repulsion_force = repulsion_force.normalized() * repulsion_weight
		
	if troupers_count > 0:
		center_of_horde /= troupers_count
		var to_center: Vector2 = (center_of_horde - enemy.global_position)
		if to_center.length_squared() > 0.0001:
			cohesion_force = to_center.normalized() * cohesion_weight
	

	
	#------------------------ GLOBAL BEHAVIOUR --------------------
	var total_forces : Vector2 = attraction_force + repulsion_force + cohesion_force
	
	if total_forces.length_squared() > 0.0001:
		enemy.velocity = total_forces.normalized() * move_speed
	else : 
		enemy.velocity = Vector2.ZERO
		
	if enemy.leader.velocity.length_squared() < 1:
		enemy.velocity = Vector2.ZERO
		attraction_force = Vector2.ZERO
		repulsion_force = Vector2.ZERO
		cohesion_force = Vector2.ZERO

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and !enemy.state_machine.is_in_state("chase"):
		state_changed.emit(self,"chase")
		SignalManager.emit_signal("player_located", enemy.horde)


func _on_day_end(_day_end : bool) -> void : 
	state_changed.emit(self,"chase")
