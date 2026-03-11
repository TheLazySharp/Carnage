class_name EnemiesManager
extends Node

#var max_enemies_per_array : int = 10
#var enemies_arrays : Array[Array] = []
var enemies_hordes : Array[Array] = []
#var enemy_added : bool = false
#var update_path_steps : float = 0.5
#var update_path_timer : float = 0.0
var enemy_groups_index : int = 0

var total_enemies : int = 0
#@onready var zombies_q: Label = $"../../CanvasLayer/Parts/MarginContainer/HBoxContainer/Zombies/ZombiesQ"


@onready var target: Node2D = $"/root/World/Car"
var game_paused:=false

func _ready() -> void:
	#if enemies_arrays.size() == 0:
		#var enemies_group : Array = []
		#enemies_arrays.append(enemies_group)
	SignalManager.connect("enemy_is_dead",_on_enemy_death)
	SignalManager.connect("player_located",_on_player_located)
	SignalManager.game_paused.connect(_on_game_paused)
	#print("nb enemies arrays :", enemies_arrays.size())


func _process(_delta: float) -> void:
	pass



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
	new_leader.scale = Vector2(2,2)

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
					
