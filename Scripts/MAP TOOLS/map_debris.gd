class_name MapDebris
extends Node2D
## Scatters debris patches on the pavement band that runs along the roads.
## Never on the roadway, never on a building footprint, never in the middle of
## a plaza: every patch is anchored on a sidewalk cell touching a road.
## Runs AFTER the building pass, since it reads the finalised cell types.

## Scene whose root is a DebrisScatter
@export var debris_scene : PackedScene = null

@export_group("Zones")
## Number of patches on the whole map, rolled per generation
@export var zone_count : Vector2i = Vector2i(10, 20)
## Patch length along the facade, in cells
@export var zone_length_cells : Vector2i = Vector2i(6, 16)
## How far the patch reaches from the wall towards the road, in cells
@export var zone_depth_cells : int = 2
## Minimum distance between two patch anchors, in cells
@export var min_distance_cells : int = 10

var _data : MapData = null
var _rng : RandomNumberGenerator = RandomNumberGenerator.new()
var _placed : Array[Vector2i] = []

const NEIGHBOURS : Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]


func build(data : MapData) -> void:
	for child : Node in get_children():
		child.queue_free()
	_placed.clear()
	_data = data

	if debris_scene == null:
		push_error("[MapDebris] no debris_scene assigned")
		return

	_rng.seed = data.seed_used ^ 0xDEB215  # own stream

	var anchors : Array[Vector2i] = _collect_anchors()
	if anchors.is_empty():
		print("[MapDebris] no pavement cell touching a road: nothing scattered")
		return

	var target : int = _rng.randi_range(zone_count.x, zone_count.y)
	var built : int = 0
	for attempt : int in target * 20:
		if built >= target:
			break
		var anchor : Vector2i = anchors[_rng.randi() % anchors.size()]
		if not _is_far_enough(anchor):
			continue
		var rect : Rect2i = _zone_rect(anchor)
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		_spawn_zone(rect)
		_placed.append(anchor)
		built += 1

	print("[MapDebris] built ", built, " debris patches over ", anchors.size(), " candidate cells")


# =================================================================
# ANCHORS
# =================================================================
func _collect_anchors() -> Array[Vector2i]:
	# Pavement cells touching a building facade: debris piles up against walls,
	# not in the middle of a crossing.
	var result : Array[Vector2i] = []
	for y : int in _data.map_size_cells.y:
		for x : int in _data.map_size_cells.x:
			if _data.cell_type(x, y) != MapData.CellType.SIDEWALK:
				continue
			if _facade_side(x, y) != Vector2i.ZERO:
				result.append(Vector2i(x, y))
	return result


func _facade_side(x : int, y : int) -> Vector2i:
	# Direction of the adjacent building, or ZERO when this pavement cell does
	# not touch one.
	for dir : Vector2i in NEIGHBOURS:
		var nx : int = x + dir.x
		var ny : int = y + dir.y
		if nx < 0 or ny < 0 or nx >= _data.map_size_cells.x or ny >= _data.map_size_cells.y:
			continue
		if _data.cell_type(nx, ny) == MapData.CellType.BUILDING:
			return dir
	return Vector2i.ZERO


func _is_pavement(cell : Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 \
		or cell.x >= _data.map_size_cells.x or cell.y >= _data.map_size_cells.y:
		return false
	return _data.cell_type(cell.x, cell.y) == MapData.CellType.SIDEWALK


func _is_far_enough(anchor : Vector2i) -> bool:
	var min_sq : int = min_distance_cells * min_distance_cells
	for other : Vector2i in _placed:
		var delta : Vector2i = anchor - other
		if delta.x * delta.x + delta.y * delta.y < min_sq:
			return false
	return true


# =================================================================
# ZONE GEOMETRY
# =================================================================
func _zone_rect(anchor : Vector2i) -> Rect2i:
	# The patch runs ALONG the facade and stays shallow, so it reads as debris
	# pushed against the wall rather than as a square dropped on the pavement.
	var facade_dir : Vector2i = _facade_side(anchor.x, anchor.y)
	if facade_dir == Vector2i.ZERO:
		return Rect2i()
	var along : Vector2i = Vector2i(-facade_dir.y, facade_dir.x)
	if _rng.randf() < 0.5:
		along = -along  # grow either way, so the anchor is not always one end
	var away : Vector2i = -facade_dir  # from the wall towards the road

	var depth : int = maxi(zone_depth_cells, 1)
	var wanted : int = _rng.randi_range(zone_length_cells.x, zone_length_cells.y)

	# Grow column by column, stopping at the first one that is not full pavement
	var used : int = 0
	for step : int in wanted:
		var column_ok : bool = true
		for d : int in depth:
			if not _is_pavement(anchor + along * step + away * d):
				column_ok = false
				break
		if not column_ok:
			break
		used += 1
	if used < zone_length_cells.x:
		return Rect2i()  # too short to read as a strip: try another anchor

	var corner_a : Vector2i = anchor
	var corner_b : Vector2i = anchor + along * (used - 1) + away * (depth - 1)
	var origin : Vector2i = Vector2i(mini(corner_a.x, corner_b.x), mini(corner_a.y, corner_b.y))
	var far : Vector2i = Vector2i(maxi(corner_a.x, corner_b.x), maxi(corner_a.y, corner_b.y))
	return Rect2i(origin, far - origin + Vector2i.ONE)


# =================================================================
# SPAWN
# =================================================================
func _spawn_zone(rect : Rect2i) -> void:
	var zone : DebrisScatter = debris_scene.instantiate() as DebrisScatter
	if zone == null:
		push_error("[MapDebris] debris_scene root must be a DebrisScatter")
		return

	zone.position = Vector2(rect.position) * float(_data.cell_size)
	var size_px : Vector2i = rect.size * _data.cell_size
	@warning_ignore("integer_division")
	zone.bounds_size = Vector2i(size_px.x / zone.pixel_size, size_px.y / zone.pixel_size)
	zone.rng_seed = int(_rng.randi())
	add_child(zone)
	zone.generate()  # DebrisScatter has no _ready hook: drive it explicitly
