class_name FlowFieldManager
extends Node2D

const CELL : float = 32.0
const REBUILD_MIN_INTERVAL : float = 0.15
const UNREACHED : int = 0x7fffffff

# Directions monde des 8 voisins (même ordre que neighbor_index_offsets)
const NEIGHBOR_DIRECTIONS : Array[Vector2] = [
	Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	Vector2(0.7071068, 0.7071068), Vector2(-0.7071068, 0.7071068),
	Vector2(0.7071068, -0.7071068), Vector2(-0.7071068, -0.7071068)
]

@export var map_origin_tile : Vector2i = Vector2i(0, 0)
@export var map_size_tiles : Vector2i = Vector2i(94, 80)

var target : Node2D = null

var grid_w : int
var grid_h : int

# Grille AVEC une bordure de 1 cellule (= mur) sur tout le pourtour :
# ça supprime tous les tests de débordement dans la boucle BFS.
var padded_width : int
var padded_height : int

var blocked : PackedByteArray         # 1 = mur (bordure incluse)
var cost : PackedInt32Array
var bfs_queue : PackedInt32Array      # file plate d'indices, préallouée une fois

# Offsets d'indices précalculés (dépendent de padded_width)
var neighbor_index_offsets : PackedInt32Array
var diagonal_ortho_a_offsets : PackedInt32Array
var diagonal_ortho_b_offsets : PackedInt32Array

var last_player_cell : Vector2i = Vector2i(0x7fffffff, 0x7fffffff)
var rebuild_timer : float = 0.0
var game_paused : bool = false
var game_over : bool = false
var field_ready : bool = false

signal walls_scanned

# --- add to members ---
var cost_back : PackedInt32Array      # written by the worker thread, swapped on completion
var rebuild_task_id : int = -1
var pending_player_cell : Vector2i

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.game_is_over.connect(_on_game_over)
	SignalManager.map_generated.connect(_on_map_generated)
	target = get_tree().get_first_node_in_group("player") as Node2D


func _on_map_generated(data : MapData) -> void:
	map_origin_tile = Vector2i.ZERO
	map_size_tiles = data.map_size_cells
	grid_w = map_size_tiles.x
	grid_h = map_size_tiles.y
	padded_width = grid_w + 2
	padded_height = grid_h + 2
	var padded_count : int = padded_width * padded_height

	blocked.resize(padded_count)
	cost.resize(padded_count)
	
	cost_back.resize(padded_count)
	cost.fill(UNREACHED)   # direct-seek fallback until the first rebuild lands
	
	bfs_queue.resize(padded_count)

	neighbor_index_offsets = PackedInt32Array([
		1, -1, padded_width, -padded_width,
		padded_width + 1, padded_width - 1, -padded_width + 1, -padded_width - 1
	])
	diagonal_ortho_a_offsets = PackedInt32Array([0, 0, 0, 0, 1, -1, 1, -1])
	diagonal_ortho_b_offsets = PackedInt32Array([0, 0, 0, 0, padded_width, padded_width, -padded_width, -padded_width])

	if target == null:
		target = get_tree().get_first_node_in_group("player") as Node2D
	scan_walls(data)
	field_ready = true

func scan_walls(data : MapData) -> void:
	blocked.fill(0)

	# Border = wall, so the BFS loop needs no bounds test
	for x : int in padded_width:
		blocked[x] = 1
		blocked[(padded_height - 1) * padded_width + x] = 1
	for y : int in padded_height:
		blocked[y * padded_width] = 1
		blocked[y * padded_width + padded_width - 1] = 1

	# Real obstacles, read straight from the generated grid
	for cell : Vector2i in data.get_blocked_cells():
		blocked[(cell.y + 1) * padded_width + (cell.x + 1)] = 1

	last_player_cell = Vector2i(0x7fffffff, 0x7fffffff)  # force a rebuild
	walls_scanned.emit()


# --- replace _process ---
func _process(delta : float) -> void:
	if !field_ready or game_paused or game_over:
		return
	# Swap in a finished rebuild first
	if rebuild_task_id != -1 and WorkerThreadPool.is_task_completed(rebuild_task_id):
		WorkerThreadPool.wait_for_task_completion(rebuild_task_id)
		rebuild_task_id = -1
		var tmp : PackedInt32Array = cost
		cost = cost_back
		cost_back = tmp
	rebuild_timer -= delta
	var player_cell : Vector2i = world_to_cell(target.global_position)
	# Never start a rebuild while one is in flight
	if rebuild_task_id == -1 and player_cell != last_player_cell and rebuild_timer <= 0.0:
		last_player_cell = player_cell
		rebuild_timer = REBUILD_MIN_INTERVAL
		pending_player_cell = player_cell
		rebuild_task_id = WorkerThreadPool.add_task(_rebuild_cost_field_task, false, "FlowField rebuild")


func _rebuild_cost_field_task() -> void:
	# Worker thread: writes ONLY cost_back. blocked and bfs_queue are never
	# touched by the main thread while a task is in flight, so no lock needed.
	cost_back.fill(UNREACHED)
	var start_x : int = clampi(pending_player_cell.x - map_origin_tile.x, 0, grid_w - 1)
	var start_y : int = clampi(pending_player_cell.y - map_origin_tile.y, 0, grid_h - 1)
	var start_index : int = (start_y + 1) * padded_width + (start_x + 1)
	cost_back[start_index] = 0
	bfs_queue[0] = start_index
	var queue_head : int = 0
	var queue_tail : int = 1
	while queue_head < queue_tail:
		var current_index : int = bfs_queue[queue_head]
		queue_head += 1
		var next_cost : int = cost_back[current_index] + 1
		for k : int in 8:
			var neighbor_index : int = current_index + neighbor_index_offsets[k]
			if blocked[neighbor_index] == 1:
				continue
			if k >= 4:   # diagonal: no corner cutting
				if blocked[current_index + diagonal_ortho_a_offsets[k]] == 1 or blocked[current_index + diagonal_ortho_b_offsets[k]] == 1:
					continue
			if cost_back[neighbor_index] != UNREACHED:
				continue
			cost_back[neighbor_index] = next_cost
			bfs_queue[queue_tail] = neighbor_index
			queue_tail += 1

# --- don't leave a task orphaned on scene exit ---
func _exit_tree() -> void:
	if rebuild_task_id != -1:
		WorkerThreadPool.wait_for_task_completion(rebuild_task_id)

# ---- API publique : direction calculée à la demande (gradient du champ de coût) ----

func get_flow_direction(world_pos: Vector2) -> Vector2:
	if !field_ready:
		return (target.global_position - world_pos).normalized() if target != null else Vector2.ZERO
	var local_x : int = int(floor(world_pos.x / CELL)) - map_origin_tile.x
	var local_y : int = int(floor(world_pos.y / CELL)) - map_origin_tile.y
	if local_x < 0 or local_y < 0 or local_x >= grid_w or local_y >= grid_h:
		return (target.global_position - world_pos).normalized()   # hors map : seek direct

	var here_index : int = (local_y + 1) * padded_width + (local_x + 1)
	var lowest_cost : int = cost[here_index]
	if lowest_cost == UNREACHED:
		return escape_direction(here_index, world_pos)

	var best_direction : Vector2 = Vector2.ZERO
	for k in range(8):
		var neighbor_index : int = here_index + neighbor_index_offsets[k]
		if blocked[neighbor_index] == 1:
			continue
		if k >= 4: 
			if blocked[here_index + diagonal_ortho_a_offsets[k]] == 1 or blocked[here_index + diagonal_ortho_b_offsets[k]] == 1:
				continue
		var neighbor_cost : int = cost[neighbor_index]
		if neighbor_cost < lowest_cost:
			lowest_cost = neighbor_cost
			best_direction = NEIGHBOR_DIRECTIONS[k]

	if best_direction == Vector2.ZERO:
		return (target.global_position - world_pos).normalized()
	return best_direction

func escape_direction(here_index : int, world_pos : Vector2) -> Vector2:
	if !target : 
		return Vector2.ZERO
	var best_cost : int = UNREACHED
	var best_direction : Vector2 = Vector2.ZERO
	for k in range(8):
		var neighbor_index : int = here_index + neighbor_index_offsets[k]
		if blocked[neighbor_index] == 1:
			continue
		var neighbor_cost : int = cost[neighbor_index]
		if neighbor_cost < best_cost:
			best_cost = neighbor_cost
			best_direction = NEIGHBOR_DIRECTIONS[k]
	if best_direction != Vector2.ZERO:
		return best_direction
	return (target.global_position - world_pos).normalized()


func is_blocked_world(world_pos : Vector2) -> bool:
	var local_x : int = int(floor(world_pos.x / CELL)) - map_origin_tile.x
	var local_y : int = int(floor(world_pos.y / CELL)) - map_origin_tile.y
	if local_x < 0 or local_y < 0 or local_x >= grid_w or local_y >= grid_h:
		return true
	return blocked[(local_y + 1) * padded_width + (local_x + 1)] == 1

# ---- utilitaires ----

#func add_obstacles(cells : Array[Vector2i]) -> void:
	#for cell : Vector2i in cells:
		#var local_x : int = cell.x - map_origin_tile.x
		#var local_y : int = cell.y - map_origin_tile.y
		#if local_x >= 0 and local_y >= 0 and local_x < grid_w and local_y < grid_h:
			#blocked[(local_y + 1) * padded_width + (local_x + 1)] = 1
	## invalide le cache pour forcer un rebuild au prochain _process (comme scan_walls)
	#last_player_cell = Vector2i(0x7fffffff, 0x7fffffff)


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))

func _on_game_paused(game_is_paused: bool) -> void:
	game_paused = game_is_paused

func _on_game_over(game_is_over: bool) -> void:
	game_over = game_is_over
