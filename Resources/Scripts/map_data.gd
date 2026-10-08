class_name MapData
extends RefCounted
## Shared result of the map generation pipeline.
## Produced by MapGenerator, consumed by every later pass (road geometry,
## buildings, props, collisions, spawns). Pure data: no node, no rendering.

enum CellType { FREE = 0, STREET = 1, ARTERY = 2, SIDEWALK = 3, BUILDING = 4, PIT = 5 }

var seed_used : int = 0
var map_size_cells : Vector2i = Vector2i.ZERO
var cell_size : int = 32

# Road metrics, copied from the generator so every pass can derive widths
var lane_width_px : int = 96
var street_lanes : int = 2
var artery_lanes : int = 4
var sidewalk_cells : int = 2

# ---------------- DISTRICT PLOT ----------------
## Plot reserved for the district building (bank, GUNSMITH...), in cells.
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

# ---------------- TRACK (oval districts) ----------------
## Closed centreline of the oval. Null on a city map.
var track_curve : Curve2D = null
## Track width in pixels
var track_width_px : int = 0
## Lap length in pixels, cached from the baked curve
var lap_length_px : float = 0.0
## Bounding box of the PIT cells, in cells (scanned by get_pit_cells)
var pit_rect : Rect2i = Rect2i()
## Pit lane centreline (open curve, entry -> exit) and its width in pixels
var pit_curve : Curve2D = null
var pit_width_px : int = 0
## Cells of the track barriers: both track edges, and between the pit lane
## and the track. They stay SIDEWALK underneath: the ground is painted below.
var barrier_cells : Array[Vector2i] = []

# Stadium geometry, set by TrackGenerator. Every lane, marking or wear line
# of the ring is an exact parallel of the centreline: see track_offset_curve().
var track_center_px : Vector2 = Vector2.ZERO
var track_radius_px : float = 0.0          # centreline turn radius
var track_half_straight_px : float = 0.0

const BEZIER_CIRCLE_K : float = 0.5523     # quarter-circle bezier handle ratio


## Closed stadium curve parallel to the track centreline.
## offset_px > 0 moves it OUTWARD, < 0 toward the infield.
## Offset 0 always sits on the start line (middle of the top straight, heading
## -X), so every corner stays a left turn.
func track_offset_curve(offset_px : float) -> Curve2D:
	var radius : float = track_radius_px + offset_px
	var hs : float = track_half_straight_px
	var c : Vector2 = track_center_px
	var handle : float = radius * BEZIER_CIRCLE_K

	var curve : Curve2D = Curve2D.new()
	curve.add_point(c + Vector2(0.0, -radius), Vector2.ZERO, Vector2.ZERO)
	curve.add_point(c + Vector2(-hs, -radius), Vector2.ZERO, Vector2.LEFT * handle)
	curve.add_point(c + Vector2(-hs - radius, 0.0), Vector2.UP * handle, Vector2.DOWN * handle)
	curve.add_point(c + Vector2(-hs, radius), Vector2.LEFT * handle, Vector2.ZERO)
	curve.add_point(c + Vector2(hs, radius), Vector2.ZERO, Vector2.RIGHT * handle)
	curve.add_point(c + Vector2(hs + radius, 0.0), Vector2.DOWN * handle, Vector2.UP * handle)
	curve.add_point(c + Vector2(hs, -radius), Vector2.RIGHT * handle, Vector2.ZERO)
	# Closing point, identical to the first: Curve2D has no closed flag
	curve.add_point(c + Vector2(0.0, -radius), Vector2.ZERO, Vector2.ZERO)
	return curve

## Racing groove as ONE closed loop: high along both straights, down to the
## apex at mid-turn, high again on exit. Starts and ends on the start line so
## the closing seam hides under it.
## Lateral offsets follow track_offset_curve(): > 0 toward the wall.
func track_groove_loop(high_px : float, apex_px : float, step_px : float = 32.0) -> PackedVector2Array:
	var hs : float = track_half_straight_px
	var steps : int = maxi(int(ceil(PI * track_radius_px / step_px)), 8)
	var points : PackedVector2Array = PackedVector2Array()
	points.append(track_center_px + Vector2(0.0, -(track_radius_px + high_px)))
	# turn 0 = LEFT turn, entered from the top straight; turn 1 = RIGHT turn.
	# The lap runs counter-clockwise on screen: the angle DECREASES along it.
	# The straights are the implicit segments between two consecutive turns.
	for turn : int in 2:
		var center : Vector2 = track_center_px + Vector2(-hs if turn == 0 else hs, 0.0)
		var a0 : float = -PI * 0.5 if turn == 0 else PI * 0.5
		for i : int in steps + 1:
			var u : float = float(i) / float(steps)
			var radius : float = track_radius_px + lerpf(high_px, apex_px, sin(PI * u))
			points.append(center + Vector2.from_angle(a0 - PI * u) * radius)
	points.append(points[0])
	return points

## Distance travelled along the lap from the start line, for any point of the
## map (projected on the centreline). Exact and O(1): the stadium is analytic.
## Range [0, 4 * half_straight + TAU * radius[.
func track_progress_at(pos : Vector2) -> float:
	var hs : float = track_half_straight_px
	var r : float = track_radius_px
	var q : Vector2 = pos - track_center_px
	if q.x < -hs:
		# Left turn, entered from the top straight
		var n : Vector2 = q + Vector2(hs, 0.0)
		return hs + r * atan2(-n.x, -n.y)
	if q.x > hs:
		# Right turn, entered from the bottom straight
		var n : Vector2 = q - Vector2(hs, 0.0)
		return 3.0 * hs + PI * r + r * atan2(n.x, n.y)
	if q.y >= 0.0:
		# Bottom straight, heading +X
		return 2.0 * hs + PI * r + q.x
	# Top straight, heading -X: the left half opens the lap, the right half closes it
	if q.x <= 0.0:
		return -q.x
	return 4.0 * hs + TAU * r - q.x


## Unit vector away from the infield at any point: the centreline normal,
## oriented toward the wall
func track_outward_at(pos : Vector2) -> Vector2:
	var hs : float = track_half_straight_px
	var q : Vector2 = pos - track_center_px
	var n : Vector2 = q - Vector2(clampf(q.x, -hs, hs), 0.0)
	if n.length_squared() < 0.0001:
		return Vector2.UP  # dead centre of the infield: any choice works
	return n.normalized()


## Unit travel direction of the lap at any point: -X on the top straight,
## +X on the bottom one, counter-clockwise on screen
func track_forward_at(pos : Vector2) -> Vector2:
	var outward : Vector2 = track_outward_at(pos)
	return Vector2(outward.y, -outward.x)


## Signed distance to the centreline: > 0 toward the wall, < 0 toward the
## infield. abs(value) > track_width_px / 2 means off the racing surface.
func track_lateral_at(pos : Vector2) -> float:
	var hs : float = track_half_straight_px
	var q : Vector2 = pos - track_center_px
	return (q - Vector2(clampf(q.x, -hs, hs), 0.0)).length() - track_radius_px

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

## Walkable for enemies: spawn cells AND flow field. On a track district
## (track_curve set) only the racing surface counts: infield, outfield and pit
## are off-limits, so every horde stands on the car's path.
func is_walkable_type(type : int) -> bool:
	if track_curve != null:
		return type == CellType.ARTERY
	return type != CellType.BUILDING

## Cells an entity may stand on (see is_walkable_type)
func get_free_cells() -> Array[Vector2i]:
	var result : Array[Vector2i] = []
	for y : int in map_size_cells.y:
		var row : int = y * map_size_cells.x
		for x : int in map_size_cells.x:
			if is_walkable_type(cells[row + x]):
				result.append(Vector2i(x, y))
	return result


## Cells blocking movement and pathfinding: the exact complement of get_free_cells()
func get_blocked_cells() -> Array[Vector2i]:
	var result : Array[Vector2i] = []
	for y : int in map_size_cells.y:
		var row : int = y * map_size_cells.x
		for x : int in map_size_cells.x:
			if not is_walkable_type(cells[row + x]):
				result.append(Vector2i(x, y))
	return result


## Cells of the pit strip. Painted with their own pavement, never as sidewalk.
func get_pit_cells() -> Array[Vector2i]:
	var result : Array[Vector2i] = []
	for y : int in range(pit_rect.position.y, pit_rect.end.y):
		for x : int in range(pit_rect.position.x, pit_rect.end.x):
			if cell_type(x, y) == CellType.PIT:
				result.append(Vector2i(x, y))
	return result
