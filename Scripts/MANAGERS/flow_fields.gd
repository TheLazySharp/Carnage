extends Node2D


var game_paused:=false

const GRID_WIDTH : int = 100
const GRID_HEIGHT : int = 100
const CELL_SIZE : int = 32

var grid : Array = []
var rects : Array = []

var from_cell : Vector2i
var to_cell : Vector2i

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause

func run_bfs() -> void:
	var path : Array = bfs(from_cell, to_cell)
	if path.size()>0:
		pass
	else: 
		print("no path found")

func reconstruct_path(parent: Dictionary, from : Vector2i, to : Vector2i) -> Array: 
	var path : Array = []
	var current : Vector2i = to
	
	while current != from:
		path.append(current)
		current = parent[current]
	
	path.append(from)
	path.reverse()
	return path

func get_neighbors(cell : Vector2i) -> Array:
	var offsets : Array = [
		Vector2i(1,0),
		Vector2i(-1,0),
		Vector2i(0,1),
		Vector2i(0,-1)
	]
	var results : Array = []
	
	for offset: Vector2i in offsets:
		var nx : int = cell.x + offset.x
		var ny : int = cell.y + offset.y
		var neighbor := Vector2i(nx,ny)
		if is_valid_cell(neighbor) : #ajouter une condition que le neighbor ne soit pas un mur (check atlas)
			results.append(neighbor)
	return results
	
func is_valid_cell(coords : Vector2i) -> bool:
	return coords.x >=0 and coords.x < GRID_WIDTH and coords.y >=0 and coords.y < GRID_HEIGHT

func get_cell_coords(target_pos : Vector2) -> Vector2i:
	var cx : int = int(target_pos.x / CELL_SIZE)
	var cy : int = int(target_pos.y / CELL_SIZE)
	return Vector2i(cx,cy)


func reset_grid() -> void:
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if rects[x][y] != null:
				remove_child(rects[x][y])
	rects.clear()

func bfs(from: Vector2i, to : Vector2i) -> Array:
	var queue: Array = []
	var visited : Dictionary = {}
	var parent : Dictionary = {}
	
	queue.append(from)
	visited[from] = true
	while queue.size() >0:
		var current : Vector2i = queue.pop_front()
		if current == to:
			return reconstruct_path(parent, from, to)
		
		for neighbor : Vector2i in get_neighbors(current):
			if !visited.has(neighbor):
				visited[neighbor] = true
				parent[neighbor] = current
				queue.append(neighbor)
	return []
