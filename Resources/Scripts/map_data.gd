class_name MapData
extends RefCounted
## Shared result of the map generation pipeline.
## Produced by MapGenerator, consumed by every later pass (road geometry,
## buildings, props, collisions, spawns). Pure data: no node, no rendering.

enum CellType { FREE = 0, STREET = 1, ARTERY = 2, SIDEWALK = 3, BUILDING = 4 }

var seed_used : int = 0
var map_size_cells : Vector2i = Vector2i.ZERO
var cell_size : int = 32

# Road metrics, copied from the generator so every pass can derive widths
var lane_width_px : int = 96
var street_lanes : int = 2
var artery_lanes : int = 4
var sidewalk_cells : int = 2

# ---------------- DISTRICT PLOT ----------------
## Plot reserved for the district building (bank, gunshop...), in cells.
## size == Vector2i.ZERO when no plot could be reserved.
var district_plot : Rect2i = Rect2i()
## Block hosting the plot: the interior fill pass must skip it entirely,
## so the district building stays alone in its block.
var district_block_id : int = -1

# ---------------- ROAD GRAPH ----------------
# Node positions are in CELL coordinates; multiply by cell_size for pixels.
var nodes : PackedVector2Array = PackedVector2Array()
var edges : Array[Vector2i] = []                        # pairs of node indices
var edge_is_artery : Array[bool] = []
var entry_node_idx : int = -1                           # left border opening (player arrival)
var exit_node_idx : int = -1                            # right border opening (extraction)
var artery_y : int = 0                                  # cell row of the main artery

# ---------------- CELL GRID ----------------
# Rasterized roads/sidewalks, row-major, one CellType byte per cell.
var cells : PackedByteArray = PackedByteArray()

# ---------------- BLOCKS ----------------
# Connected FREE regions (flood fill). Blocks can be L-shaped after street
# removal: block_rects is only the bounding box, always check cell_block_id.
var cell_block_id : PackedInt32Array = PackedInt32Array()  # per cell, -1 = not FREE
var block_rects : Array[Rect2i] = []                    # bounding box per block (cells)
var block_areas : PackedInt32Array = PackedInt32Array() # FREE cell count per block


func street_width_px() -> float:
	return float(street_lanes * lane_width_px)


func artery_width_px() -> float:
	return float(artery_lanes * lane_width_px)


func edge_width_px(edge_idx : int) -> float:
	return artery_width_px() if edge_is_artery[edge_idx] else street_width_px()


func sidewalk_width_px() -> float:
	return float(sidewalk_cells * cell_size)


func cell_index(x : int, y : int) -> int:
	return y * map_size_cells.x + x


func cell_type(x : int, y : int) -> int:
	return cells[y * map_size_cells.x + x]


func is_road(x : int, y : int) -> bool:
	var t : int = cells[y * map_size_cells.x + x]
	return t == CellType.STREET or t == CellType.ARTERY


func is_free(x : int, y : int) -> bool:
	return cells[y * map_size_cells.x + x] == CellType.FREE


# ---------------- BUILDINGS / SIDEWALKS ----------------
## Called by the building placement pass for each placed footprint
func mark_building(rect : Rect2i) -> void:
	for y : int in range(maxi(rect.position.y, 0), mini(rect.end.y, map_size_cells.y)):
		var row : int = y * map_size_cells.x
		for x : int in range(maxi(rect.position.x, 0), mini(rect.end.x, map_size_cells.x)):
			cells[row + x] = CellType.BUILDING


## True when the rect is fully inside the map and every cell is still FREE
func can_place_building(rect : Rect2i) -> bool:
	if rect.position.x < 0 or rect.position.y < 0:
		return false
	if rect.end.x > map_size_cells.x or rect.end.y > map_size_cells.y:
		return false
	for y : int in range(rect.position.y, rect.end.y):
		var row : int = y * map_size_cells.x
		for x : int in range(rect.position.x, rect.end.x):
			if cells[row + x] != CellType.FREE:
				return false
	return true


## Called ONCE after all buildings are placed: whatever is left between roads
## and buildings is pavement. Must run before painting the sidewalk layer.
func finalize_sidewalks() -> void:
	for i : int in cells.size():
		if cells[i] == CellType.FREE:
			cells[i] = CellType.SIDEWALK


## Every cell that is not a road: whole block interiors (building footprints
## included, since buildings are drawn on top) plus the bands along the roads.
## A block with no building therefore reads as a plaza.
func get_sidewalk_cells() -> Array[Vector2i]:
	var result : Array[Vector2i] = []
	for y : int in map_size_cells.y:
		var row : int = y * map_size_cells.x
		for x : int in map_size_cells.x:
			var type : int = cells[row + x]
			if type != CellType.STREET and type != CellType.ARTERY:
				result.append(Vector2i(x, y))
	return result


func cell_to_world(cell : Vector2i) -> Vector2:
	return Vector2(cell) * float(cell_size)


func world_to_cell(world_pos : Vector2) -> Vector2i:
	return Vector2i((world_pos / float(cell_size)).floor())
