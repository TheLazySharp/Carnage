class_name FlowFieldManagerOnePass extends Node2D

var flow_field: PackedVector2Array = PackedVector2Array()
var costs: PackedInt32Array = PackedInt32Array()

@export var field_size: Vector2 = Vector2(64, 48)
@onready var bounds: = Rect2i(Vector2i.ZERO - Vector2i(field_size)/2, field_size)

@export var tile_map: TileMapLayer
@export var flow_field_tilemap: TileMapLayer

const TILE_SIZE: int = 16
const MAX_COST: int = 999999

@export var target: Node2D
@export var show_debug_arrows: bool = false:
	set(val):
		show_debug_arrows = val
		if not flow_field_tilemap:
			return
		flow_field_tilemap.visible = show_debug_arrows
var target_tile: Vector2i = Vector2i.ZERO

const DIRECTIONS = [Vector2.UP,
Vector2(1, -1), Vector2.RIGHT, Vector2.ONE, Vector2.DOWN, Vector2(-1,1), Vector2.LEFT, Vector2(-1,-1), Vector2.ZERO]

func _ready() -> void:
	initialize_field()
	generate_flow_field(true)

func initialize_field() -> void:
	for x in field_size.x:
		for y in field_size.y:
			flow_field.append(Vector2.ZERO)
			costs.append(MAX_COST)

func get_field_index(cell: Vector2i) -> int:
	# Check if the cell is outside the bounds
	if not bounds.encloses(Rect2i(cell, Vector2i.ONE)):
		return -1
	#vector pointing from bounds to cell
	var offset := cell - bounds.position
	var index: int = offset.y * bounds.size.x + offset.x
	return index

func index_to_cell(index: int) -> Vector2i:
	var x : int = index % bounds.size.x
	var y : int = index / bounds.size.x
	return Vector2i(x, y) + bounds.position

func add_cost_to_cell(pos: Vector2i) -> void:
	var index: int = get_field_index(Vector2i(pos / TILE_SIZE))
	costs[index] += 1


func get_field_direction(pos: Vector2) -> Vector2:
	var index: int = get_field_index(Vector2i(pos / TILE_SIZE))
	if index < 0 or index >= flow_field.size():
		push_error('cant find flow field direction')
		return Vector2.ZERO
	return flow_field[index].normalized()

func get_neighbor_cells(current_cell : Vector2i) -> Array[Vector2i]:
	return [current_cell + Vector2i.UP,current_cell + Vector2i.RIGHT,current_cell + Vector2i.DOWN,current_cell + Vector2i.LEFT, current_cell + Vector2i(-1,-1), current_cell + Vector2i(1,-1),current_cell + Vector2i(1,1), current_cell + Vector2i(-1,1)]

func _physics_process(delta: float) -> void:
	generate_flow_field()
	
func generate_flow_field(force: bool = false) -> void:
	var next_target_tile: Vector2i = Vector2i((target.global_position / TILE_SIZE).floor())
	
	if not force and next_target_tile == target_tile:
		return

	target_tile = next_target_tile
	bounds.position = target_tile - Vector2i(field_size)/2
	costs[get_field_index(target_tile)] = 0
	
	var cost_queue: Array[Vector2i] = [target_tile]
	var seen: Dictionary = {}
	
	while not cost_queue.is_empty():
		var current_cell : Vector2i= cost_queue.pop_front()
		seen[current_cell] = true
		
		var index: int = get_field_index(current_cell)
		if costs[index] == MAX_COST:
			continue

		for neighbor_cell in get_neighbor_cells(current_cell):
			# don't revisit already seen cells and skip out of bounds cells
			var neighbor_cell_index: int = get_field_index(neighbor_cell)
			if seen.has(neighbor_cell) or neighbor_cell_index == -1:
				continue
			
			var tile_data: TileData = tile_map.get_cell_tile_data(neighbor_cell)
			var travel_cost: int = 1
			if tile_data and tile_data.get_collision_polygons_count(0) > 0:
				costs[neighbor_cell_index] = MAX_COST
				flow_field[neighbor_cell_index] = Vector2.ZERO
			else:
				costs[neighbor_cell_index] = costs[index] + travel_cost
				cost_queue.append(neighbor_cell)
			
				flow_field[neighbor_cell_index] = Vector2(current_cell - neighbor_cell)
			
			cost_queue.append(neighbor_cell)
			seen[neighbor_cell] = true
			flow_field_tilemap.set_cell(neighbor_cell, 0, Vector2i(DIRECTIONS.find(flow_field[neighbor_cell_index]), 0))
	
