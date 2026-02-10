class_name EnemiesManager
extends Node

var max_enemies_per_array : int = 10
var enemies_arrays : Array[Array]
var enemy_added : bool = false
var update_path_steps : float = 0.5
var update_path_timer : float = 0.0
var enemy_groups_index : int = 0

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
	if !enemies_arrays[0].is_empty():
		for i in enemies_arrays.size():
			var array : Array = enemies_arrays[i]
			for j in range(array.size()-1,-1,-1):
				if array[j] == dead_enemy:
					array.remove_at(j)
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
