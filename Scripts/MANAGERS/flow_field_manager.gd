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
@export var map_size_tiles : Vector2i = Vector2i(94, 63)

@onready var target : Node2D = $"/root/World/Car"

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


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.game_is_over.connect(_on_game_over)

	grid_w = map_size_tiles.x
	grid_h = map_size_tiles.y
	padded_width = grid_w + 2
	padded_height = grid_h + 2
	var padded_count : int = padded_width * padded_height

	blocked.resize(padded_count)
	cost.resize(padded_count)
	bfs_queue.resize(padded_count)

	# Offsets des 8 voisins, en indices plats (ordre = NEIGHBOR_DIRECTIONS)
	neighbor_index_offsets = PackedInt32Array([
		1, -1, padded_width, -padded_width,
		padded_width + 1, padded_width - 1, -padded_width + 1, -padded_width - 1
	])
	# Pour chaque diagonale (indices 4..7) : les 2 voisins orthogonaux à tester
	# pour interdire le passage en coin de mur. Indices 0..3 inutilisés.
	diagonal_ortho_a_offsets = PackedInt32Array([0, 0, 0, 0, 1, -1, 1, -1])
	diagonal_ortho_b_offsets = PackedInt32Array([0, 0, 0, 0, padded_width, padded_width, -padded_width, -padded_width])

	scan_walls.call_deferred()


func scan_walls() -> void:
	blocked.fill(0)

	# Bordure = mur (premières/dernières lignes et colonnes paddées)
	for x in range(padded_width):
		blocked[x] = 1
		blocked[(padded_height - 1) * padded_width + x] = 1
	for y in range(padded_height):
		blocked[y * padded_width] = 1
		blocked[y * padded_width + padded_width - 1] = 1

	# Murs réels
	for wall in get_tree().get_nodes_in_group("walls"):
		if wall is TileMapLayer:
			for wall_cell : Vector2i in wall.get_used_cells():
				var local_x : int = wall_cell.x - map_origin_tile.x
				var local_y : int = wall_cell.y - map_origin_tile.y
				if local_x >= 0 and local_y >= 0 and local_x < grid_w and local_y < grid_h:
					blocked[(local_y + 1) * padded_width + (local_x + 1)] = 1

	last_player_cell = Vector2i(0x7fffffff, 0x7fffffff)   # force un rebuild


func _process(delta: float) -> void:
	if game_paused or game_over:
		return
	rebuild_timer -= delta
	var player_cell : Vector2i = world_to_cell(target.global_position)
	if player_cell != last_player_cell and rebuild_timer <= 0.0:
		last_player_cell = player_cell
		rebuild_timer = REBUILD_MIN_INTERVAL
		rebuild_cost_field(player_cell)


func rebuild_cost_field(player_cell: Vector2i) -> void:
	cost.fill(UNREACHED)

	var start_x : int = clampi(player_cell.x - map_origin_tile.x, 0, grid_w - 1)
	var start_y : int = clampi(player_cell.y - map_origin_tile.y, 0, grid_h - 1)
	var start_index : int = (start_y + 1) * padded_width + (start_x + 1)

	cost[start_index] = 0
	bfs_queue[0] = start_index
	var queue_head : int = 0
	var queue_tail : int = 1

	while queue_head < queue_tail:
		var current_index : int = bfs_queue[queue_head]
		queue_head += 1
		var next_cost : int = cost[current_index] + 1

		for k in range(8):
			var neighbor_index : int = current_index + neighbor_index_offsets[k]
			if blocked[neighbor_index] == 1:
				continue
			if k >= 4:   # diagonale : pas de passage en coin de mur
				if blocked[current_index + diagonal_ortho_a_offsets[k]] == 1 or blocked[current_index + diagonal_ortho_b_offsets[k]] == 1:
					continue
			if cost[neighbor_index] != UNREACHED:
				continue
			cost[neighbor_index] = next_cost
			bfs_queue[queue_tail] = neighbor_index
			queue_tail += 1


# ---- API publique : direction calculée à la demande (gradient du champ de coût) ----

func get_flow_direction(world_pos: Vector2) -> Vector2:
	var local_x : int = int(floor(world_pos.x / CELL)) - map_origin_tile.x
	var local_y : int = int(floor(world_pos.y / CELL)) - map_origin_tile.y
	if local_x < 0 or local_y < 0 or local_x >= grid_w or local_y >= grid_h:
		return (target.global_position - world_pos).normalized()   # hors map : seek direct

	var here_index : int = (local_y + 1) * padded_width + (local_x + 1)
	var lowest_cost : int = cost[here_index]
	if lowest_cost == UNREACHED:
		return (target.global_position - world_pos).normalized()   # cellule injoignable : fallback

	var best_direction : Vector2 = Vector2.ZERO
	for k in range(8):
		var neighbor_cost : int = cost[here_index + neighbor_index_offsets[k]]
		if neighbor_cost < lowest_cost:
			lowest_cost = neighbor_cost
			best_direction = NEIGHBOR_DIRECTIONS[k]

	if best_direction == Vector2.ZERO:
		return (target.global_position - world_pos).normalized()
	return best_direction


# ---- utilitaires ----

func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))

func _on_game_paused(game_is_paused: bool) -> void:
	game_paused = game_is_paused

func _on_game_over(game_is_over: bool) -> void:
	game_over = game_is_over
