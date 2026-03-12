class_name EnemiesManager
extends Node

var enemies_hordes : Array[Array] = []
var total_enemies : int = 0
var distance_check_timer : float = 0
var distance_check_steps : float = 0.5


@onready var target: Node2D = $"/root/World/Car"
var game_paused:=false

func _ready() -> void:
	SignalManager.connect("enemy_is_dead",_on_enemy_death)
	SignalManager.connect("player_located",_on_player_located)
	SignalManager.game_paused.connect(_on_game_paused)


func _process(delta: float) -> void:
	if game_paused:
		return
	distance_check_timer += delta
	if distance_check_timer < distance_check_steps:
		return
	distance_check_timer = 0
	update_physics_rates()

func update_physics_rates() -> void:
	for horde in enemies_hordes:
		for enemy : Enemy in horde:
			if !is_instance_valid(enemy):
				continue
			var dist_sq : float = enemy.global_position.distance_squared_to(target.global_position)
			if dist_sq < 100 * 100:
				enemy.physics_skip_max = 1
			if dist_sq < 200 * 200:
				enemy.physics_skip_max = 2
			else :
				enemy.physics_skip_max = 3
				

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
	new_leader.is_leader = true
	new_leader.multimesh_set_color(Color.BLACK)

	for i in range(new_leader_horde.size() -1,-1,-1):
		if !is_instance_valid(new_leader_horde[i]):
			continue
		else: 
			if new_leader_horde[i] == new_leader:
				new_leader_horde[i].leader = null
			else :
				new_leader_horde[i].leader = new_leader

func _on_player_located(locator_horde : Array)->void:
	if !enemies_hordes.is_empty():
		for i in range(enemies_hordes.size()-1,-1,-1):
			var horde : Array = enemies_hordes[i]
			if horde == locator_horde:
				for j in range(horde.size()-1,-1,-1):
						if !is_instance_valid(horde[j]):
							continue
						horde[j].state_machine.state_transition_to("chase")
					
