class_name EnemiesManager
extends Node

var max_enemies_per_array : int = 10
var enemies_arrays : Array[Array]
var enemies_hordes : Array[Array]
var enemy_added : bool = false
var update_path_steps : float = 0.5
var update_path_timer : float = 0.0
var enemy_groups_index : int = 0

var total_enemies : int = 0
#@onready var zombies_q: Label = $"../../CanvasLayer/Parts/MarginContainer/HBoxContainer/Zombies/ZombiesQ"


@onready var gm_scene: Node = $"/root/World/game_manager"
@onready var target: Node2D = $"/root/World/Car"
var game_paused:=false

func _ready() -> void:
	if enemies_arrays.size() == 0:
		var enemies_group : Array = []
		enemies_arrays.append(enemies_group)
	SignalManager.connect("enemy_chasing",enemy_chasing)
	SignalManager.connect("enemy_is_dead",_on_enemy_death)
	SignalManager.connect("enemy_exiting_chase",_on_exiting_chase)
	gm_scene.game_paused.connect(_on_game_paused)
	print("nb enemies arrays :", enemies_arrays.size())

func _process(delta: float) -> void:
	#zombies_q.text = str(total_enemies)
	leaders_check()
	if game_paused: return
	
	update_path_timer += delta
	if update_path_timer < update_path_steps:
		return
	update_path_timer = 0.0
	
	if enemies_arrays.is_empty():
		return
	
	if enemy_groups_index >= enemies_arrays.size():
		enemy_groups_index = 0
	
	var new_group : Array = enemies_arrays[enemy_groups_index]
	for j in range(new_group.size()-1,-1,-1):
		if new_group[j]:
			var enemy : Enemy = new_group[j]
			if enemy == null or !is_instance_valid(enemy):
				new_group.remove_at(j)
				continue
			
			var navigation_agent : NavigationAgent2D = enemy.get_node("NavigationAgent2D")
			navigation_agent.target_position = target.global_position
	enemy_groups_index += 1 % enemies_arrays.size()
	
	

func enemy_chasing(enemy : Enemy)-> void:
	enemy_added = false

	for i in enemies_arrays.size():
		var array : Array = enemies_arrays[i]
		if array.size() < max_enemies_per_array:
			array.append(enemy)
			enemy_added = true
			break
			
	if !enemy_added: 
		var new_enemies_group : Array = []
		new_enemies_group.append(enemy)
		enemies_arrays.append(new_enemies_group)



func _on_enemy_death(dead_enemy : Enemy) -> void : 
	#check if dead enemy is in IA array to remove from this array
	if !enemies_arrays[0].is_empty():
		for i in enemies_arrays.size():
			var array : Array = enemies_arrays[i]
			for j in range(array.size()-1,-1,-1):
				if array[j] == dead_enemy:
					array.remove_at(j)
					
					#check if dead enemy is in a horde to remove it from this array
					if !enemies_hordes.is_empty():
						for k in range(enemies_hordes.size()-1,-1,-1):
							var horde : Array = enemies_hordes[k]
							if !horde.is_empty():
								for n in range(horde.size()-1,-1,-1):
									if horde[n] == dead_enemy:
										horde.remove_at(n)
					dead_enemy.queue_free()
					break
	else : dead_enemy.queue_free()

func _on_exiting_chase(exited_enemy : Enemy) -> void: 
	if !enemies_arrays[0].is_empty():
		for i in enemies_arrays.size():
			var array : Array = enemies_arrays[i]
			for j in range(array.size()-1,-1,-1):
				if array[j] == exited_enemy:
					array.erase(exited_enemy)
					break

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
	
func count_enemies(n : int) -> void:
	total_enemies += n

func leaders_check() -> void:
	if !enemies_hordes.is_empty():
		for i in range(enemies_hordes.size()-1,-1,-1):
			var horde : Array = enemies_hordes[i]
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
							#horde[j].is_leader = true
							#horde[j].scale = Vector2(2,2)
							set_new_leader(horde[j],horde)
							
							break

func set_new_leader(new_leader : Enemy, new_leader_horde : Array) -> void:
	new_leader.is_leader = true
	new_leader.scale = Vector2(2,2)

	for i in range(new_leader_horde.size() -1,-1,-1):
		if !is_instance_valid(new_leader_horde[i]):
			continue
		else: 
			if new_leader_horde[i] == new_leader:
				new_leader_horde[i].leader = null
			else :
				new_leader_horde[i].leader = new_leader
