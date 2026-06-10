class_name HordeManager
extends Node2D

var enemies_hordes : Array[Array] = []
var total_enemies : int = 0

#CHAINED IMPACT DETECTIONS STAGGER
var distance_check_timer : float = 0
var distance_check_steps : float = 0.5

#WALL DETECTION STAGGER
@export var wall_detection_radius: float = 120.0
@export var wall_collision_mask: int = 8
var wall_check_timer: float = 0.0
var wall_check_steps: float = 0.5

#PLAYER DETECTION STAGGER
var detection_radius_sq : int = 140 * 140
var detection_timer: float = 0.0
var detection_timer_steps: float = 0.3

@onready var target: Node2D = $"/root/World/Car"
var game_paused: bool =false
var game_over : bool = false

func _ready() -> void:
	SignalManager.connect("enemy_is_dead",_on_enemy_death)
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.game_is_over.connect(_on_game_over)



func _process(delta: float) -> void:
	if game_paused:
		return
	
	if game_over:
		return
	
	detection_timer += delta
	if detection_timer >= detection_timer_steps:
		detection_timer = 0
		update_player_detection()

	distance_check_timer += delta
	if distance_check_timer < distance_check_steps:
		return
	distance_check_timer = 0
	update_physics_rates()


func _physics_process(delta: float) -> void:
	wall_check_timer += delta
	if wall_check_timer < wall_check_steps:
		return
	wall_check_timer = 0
	update_walls_proximity()


func update_physics_rates() -> void:
	for horde in enemies_hordes:
		for i in range(horde.size()-1,-1,-1):
			if !is_instance_valid(horde[i]):
				continue
			var dist_sq : float = horde[i].global_position.distance_squared_to(target.global_position)
			if dist_sq < 100 * 100:
				horde[i].physics_skip_steps = 0.016
			if dist_sq < 200 * 200:
				horde[i].physics_skip_steps = 0.032
			else :
				horde[i].physics_skip_steps = 0.050

func update_walls_proximity() -> void : 
	var space := get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = wall_detection_radius
	params.shape = circle
	params.collision_mask = wall_collision_mask
 
	for horde in enemies_hordes:
		for i in range(horde.size()-1,-1,-1):
			if !is_instance_valid(horde[i]):
				continue
			params.transform = Transform2D(0.0, horde[i].global_position)
			var results := space.intersect_shape(params, 1)
			horde[i].near_wall = !results.is_empty()


func _on_enemy_death(dead_enemy : Enemy, dead_enemy_horde : Array) -> void : 
	if dead_enemy_horde != null:
		dead_enemy_horde.erase(dead_enemy)
	
	var was_leader : bool = dead_enemy.is_leader
	dead_enemy.queue_free()
	if was_leader :
		leaders_check(dead_enemy_horde)
		


func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
	
func count_enemies(n : int) -> void:
	total_enemies += n

func leaders_check(horde : Array) -> void:
	if !horde.is_empty():
		var nb_leader : int = 0
		for j in range(horde.size()-1,-1,-1):
			if !is_instance_valid(horde[j]):
				continue
			if horde[j].is_leader and is_instance_valid(horde[j]):
				nb_leader += 1
				break
		if nb_leader == 0 :
			for j in range(horde.size()-1,-1,-1):
				if is_instance_valid(horde[j]):
					set_new_leader(horde[j],horde)
					break

func set_new_leader(new_leader : Enemy, new_leader_horde : Array) -> void:
	if game_over:
		return
	new_leader.is_leader = true
	#new_leader.set_enemy_color(Color.BLACK)

	for i in range(new_leader_horde.size() -1,-1,-1):
		if !is_instance_valid(new_leader_horde[i]):
			continue
		else: 
			if new_leader_horde[i] == new_leader:
				new_leader_horde[i].leader = null
			else :
				new_leader_horde[i].leader = new_leader

func update_player_detection() -> void:
	if game_over:
		return
	var player_pos := target.global_position
	for horde in enemies_hordes:
		if horde.size() > 0 and is_instance_valid(horde[0]):
			if horde[0].state_machine.is_in_state("chase"):
				continue
		
		for i in range(horde.size() -1,-1,-1):
			if !is_instance_valid(horde[i]): 
				continue
			if horde[i].global_position.distance_squared_to(player_pos) < detection_radius_sq:
				#if !enemy.state_machine.is_in_state("chase"):
				for j in range(horde.size() -1,-1,-1):
					if is_instance_valid(horde[j]):
						horde[j].state_machine.state_transition_to("chase")
				break

func _on_game_over(game_is_over : bool)-> void : 
	game_over = game_is_over
