class_name HordeManager
extends Node2D

var enemies_hordes : Array[Array] = []
var total_enemies : int = 0

# ---- ROUND-ROBIN BUDGET ----
const RATES_PER_FRAME : int = 40      # ennemis traités par frame
var rates_h : int = 0                 # curseur horde
var rates_i : int = 0                 # curseur ennemi

const NEIGHBOR_RADIUS_SQ : float = 400.0   # ex neighbors_detection_radius_sq de enemy_multimesh.gd
var neighbors_horde_cursor : int = 0

# ---- WALL GRID ----
const WALL_CELL : float = 32.0
@export var wall_detection_radius: float = 64
var wall_cells : Dictionary = {}      # Vector2i -> true

# ---------- PLAYER DETECTION --------
var detection_radius_sq : int = 140 * 140
var detection_horde_cursor : int = 0

@onready var target: Node2D = $"/root/World/Car"
var game_paused: bool =false
var game_over : bool = false

signal wall_grid_ready


func _ready() -> void:
	SignalManager.enemy_is_dead.connect(_on_enemy_death)
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.game_is_over.connect(_on_game_over)
	build_wall_grid.call_deferred()


func _process(_delta: float) -> void:
	if game_paused or game_over:
		return
	step_physics_rates()      # budget : RATES_PER_FRAME ennemis / frame
	step_neighbors()          # 1 horde / frame
	step_player_detection()   # 1 horde / frame


func build_wall_grid() -> void:
	wall_cells.clear()
	var margin_cells : int = ceili(wall_detection_radius / WALL_CELL)

	for wall in get_tree().get_nodes_in_group("walls"):
		if wall is TileMapLayer:
			for cell : Vector2i in wall.get_used_cells():
				mark_cell_with_margin(cell, margin_cells)
	
	wall_grid_ready.emit() 

func add_wall_cells(cells : Array[Vector2i]) -> void:
	var margin_cells : int = ceili(wall_detection_radius / WALL_CELL)
	for cell : Vector2i in cells:
		mark_cell_with_margin(cell, margin_cells)


func mark_cell_with_margin(cell: Vector2i, margin: int) -> void:
	for dy in range(-margin, margin + 1):
		for dx in range(-margin, margin + 1):
			wall_cells[cell + Vector2i(dx, dy)] = true

func is_near_wall(pos: Vector2) -> bool:
	return wall_cells.has(Vector2i((pos / WALL_CELL).floor()))


# ----- ROUND ROBIN -----

func step_physics_rates() -> void:
	if enemies_hordes.is_empty():
		return
	var budget : int = RATES_PER_FRAME
	var player_pos : Vector2 = target.global_position

	while budget > 0:
		if rates_h >= enemies_hordes.size():
			rates_h = 0
			return   # sweep complet terminé, reprendra à la frame suivante
		
		var horde: Array = enemies_hordes[rates_h]
		if rates_i >= horde.size():
			rates_h += 1
			rates_i = 0
			continue
		var enemy : Enemy = horde[rates_i]
		rates_i += 1
		if !is_instance_valid(enemy):
			continue
		budget -= 1

		var dist_sq : float = enemy.global_position.distance_squared_to(player_pos)
		if dist_sq < 100 * 100:
			enemy.physics_skip_steps = 0.016
		elif dist_sq < 200 * 200:
			enemy.physics_skip_steps = 0.032
		else:
			enemy.physics_skip_steps = 0.050

func step_neighbors() -> void:
	if enemies_hordes.is_empty():
		return
	neighbors_horde_cursor = (neighbors_horde_cursor + 1) % enemies_hordes.size()
	var horde: Array = enemies_hordes[neighbors_horde_cursor]

	for enemy : Enemy in horde:
		if is_instance_valid(enemy):
			enemy.horde_neighbors.clear()

	for i in range(horde.size()):
		var enemy_a : Enemy = horde[i]
		if !is_instance_valid(enemy_a):
			continue
		var enemy_a_pos : Vector2 = enemy_a.global_position
		for j in range(i + 1, horde.size()):
			var enemy_b : Enemy = horde[j]
			if !is_instance_valid(enemy_b):
				continue
			if enemy_a_pos.distance_squared_to(enemy_b.global_position) < NEIGHBOR_RADIUS_SQ:
				enemy_a.horde_neighbors.append(enemy_b)
				enemy_b.horde_neighbors.append(enemy_a)

func step_player_detection() -> void:
	if enemies_hordes.is_empty():
		return
	detection_horde_cursor = (detection_horde_cursor + 1) % enemies_hordes.size()
	var horde: Array = enemies_hordes[detection_horde_cursor]
	if horde.is_empty():
		return
	if is_instance_valid(horde[0]) and horde[0].state_machine.is_in_state("chase"):
		return

	var player_pos : Vector2 = target.global_position
	for i in range(horde.size() - 1, -1, -1):
		if !is_instance_valid(horde[i]):
			continue
		if horde[i].global_position.distance_squared_to(player_pos) < detection_radius_sq:
			for j in range(horde.size() - 1, -1, -1):
				if is_instance_valid(horde[j]):
					horde[j].state_machine.state_transition_to("chase")
			return

func _on_enemy_death(dead_enemy : Enemy, dead_enemy_horde : Array) -> void : 
	if dead_enemy_horde != null:
		dead_enemy_horde.erase(dead_enemy)
	
	var was_leader : bool = dead_enemy.is_leader
	#dead_enemy.queue_free()
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
