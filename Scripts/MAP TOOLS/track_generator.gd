class_name TrackGenerator
extends RefCounted
## Builds an oval speedway into a MapData:
##   1. centreline : a closed Curve2D (stadium: 2 straights + 4 quarter arcs)
##   2. cell grid  : track / pit / infield / outfield rasterized into MapData
##
## The raster is what every downstream pass reads (sidewalks, buildings,
## spawners, flow field), so the oval stays compatible with the city pipeline.
## No block extraction: the belt pass only tests the map border, and nothing
## is ever built on the infield, so every cell_block_id stays at -1.

const BEZIER_CIRCLE_K : float = 0.5523  # quarter-circle bezier handle ratio

# ---------------- MAP PARAMETERS ----------------
var map_size_cells : Vector2i = Vector2i(96, 80)
var cell_size : int = 32
var lane_width_px : int = 96
var track_lanes : int = 4                   # 4 x 96 px = 384 px = 12 cells

# ---------------- TRACK PARAMETERS ----------------
## Gap kept between the OUTER edge of the track and the map border, in cells.
## H = left/right, V = top/bottom. Raise V to flatten the oval.
var border_margin_h_cells : int = 2
var border_margin_v_cells : int = 8
## Pit lane: along the BOTTOM straight, on the infield side, opposite the
## start/finish line. Narrower than the track.
var pit_lanes : int = 2
## Grass between the track's inner edge and the pit lane, in cells
var pit_gap_cells : int = 2
## How far into each turn the pit lane leaves / rejoins the track, in degrees
## measured from the straight
var pit_ramp_angle_deg : float = 50.0

# Derived from the map size in _fit_to_map(), read-only for the callers
var corner_radius_cells : int = 0
var straight_cells : int = 0

var _data : MapData = null

func _set_anchors() -> void:
	# The city pipeline hands its consumers a road graph: HordeSpawner keeps
	# hordes away from nodes[entry_node_idx], DayManager reads its exit from
	# nodes[exit_node_idx]. On the ring both are the start/finish line, stored
	# as a single node in CELL coordinates.
	var start_cell : Vector2 = _data.track_curve.sample_baked(0.0) / float(cell_size)
	_data.nodes = PackedVector2Array([start_cell])
	_data.entry_node_idx = 0
	_data.exit_node_idx = 0
	_data.artery_y = int(start_cell.y)

func generate(map_seed : int = 0) -> MapData:
	_data = MapData.new()
	_data.seed_used = map_seed if map_seed != 0 \
			else abs(int(Time.get_unix_time_from_system() * 1000.0)) % 2147483647

	_data.map_size_cells = map_size_cells
	_data.cell_size = cell_size
	_data.lane_width_px = lane_width_px
	_data.street_lanes = track_lanes
	_data.artery_lanes = track_lanes
	_data.sidewalk_cells = 0

	_fit_to_map()
	_build_curve()
	_set_anchors()
	_rasterize_cells()
	_reset_blocks()

	print("[TrackGenerator] seed ", _data.seed_used,
			" | R ", corner_radius_cells, " straights ", straight_cells,
			" | lap ", int(_data.lap_length_px / float(cell_size)), " cells (",
			int(_data.lap_length_px / float(cell_size) * 2.25), " m)",
			" | track ", track_width_cells(), " cells")
	return _data


func track_width_px() -> int:
	return track_lanes * lane_width_px


func track_width_cells() -> int:
	@warning_ignore("integer_division")
	return track_width_px() / cell_size

func _fit_to_map() -> void:
	# The oval fills the map, leaving the requested margin on each axis.
	# The HEIGHT sets the turn radius, the WIDTH gets whatever is left for the
	# straights: raising border_margin_v_cells tightens the turns and stretches
	# the straights, which is exactly what flattens the oval.
	var w : int = track_width_cells()
	var usable_h : int = map_size_cells.y - 2 * border_margin_v_cells - w
	var usable_w : int = map_size_cells.x - 2 * border_margin_h_cells - w
	corner_radius_cells = int(floor(float(usable_h) * 0.5))
	# Never wider than the map allows, never tighter than a full track width:
	# the infield must keep a real hole in the middle
	corner_radius_cells = mini(corner_radius_cells, int(floor(float(usable_w) * 0.5)))
	corner_radius_cells = maxi(corner_radius_cells, w)
	straight_cells = maxi(usable_w - 2 * corner_radius_cells, 0)


# =================================================================
# PASS 1 : CENTRELINE
# =================================================================
func _build_curve() -> void:
	var px : float = float(cell_size)
	_data.track_center_px = Vector2(map_size_cells) * 0.5 * px
	_data.track_radius_px = float(corner_radius_cells) * px
	_data.track_half_straight_px = float(straight_cells) * 0.5 * px
	_data.track_curve = _data.track_offset_curve(0.0)
	_data.track_width_px = track_width_px()
	_data.lap_length_px = _data.track_curve.get_baked_length()


# =================================================================
# PASS 2 : CELL GRID
# =================================================================
func _rasterize_cells() -> void:
	var w : int = map_size_cells.x
	var h : int = map_size_cells.y
	_data.cells.resize(w * h)
	# Everything is ground by default: the racing surface and the pit lane
	# are carved into it below
	_data.cells.fill(MapData.CellType.SIDEWALK)

	var px : float = float(cell_size)
	var radius : float = float(corner_radius_cells) * px
	var half_track : float = float(track_width_px()) * 0.5
	var center : Vector2 = Vector2(map_size_cells) * 0.5 * px
	var half_straight : float = float(straight_cells) * 0.5 * px
	var c1 : Vector2 = center + Vector2(-half_straight, 0.0)
	var c2 : Vector2 = center + Vector2(half_straight, 0.0)

	# Closed form: the oval is the set of points at a fixed distance from the
	# SEGMENT joining the two turn centres. No curve sampling, no per-cell loop
	# over baked points.
	for y : int in range(h):
		for x : int in range(w):
			var p : Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5)) * px
			if absf(_distance_to_segment(p, c1, c2) - radius) <= half_track:
				_data.cells[y * w + x] = MapData.CellType.ARTERY

	_build_pit_lane()


func _build_pit_lane() -> void:
	# Pit lane along the BOTTOM straight, on the infield side: opposite the
	# start/finish line. It leaves the inner lane pit_ramp_angle_deg before the
	# end of the left turn and rejoins it pit_ramp_angle_deg into the right turn.
	var px : float = float(cell_size)
	var hs : float = _data.track_half_straight_px
	var radius : float = _data.track_radius_px
	var center : Vector2 = _data.track_center_px
	var lane_w : float = float(lane_width_px)
	var half_track : float = float(track_width_px()) * 0.5
	var pit_w : float = float(pit_lanes) * lane_w
	var ramp : float = deg_to_rad(pit_ramp_angle_deg)

	# Straight part, parallel to the bottom straight, inside the infield
	var pit_y : float = center.y + radius - half_track - float(pit_gap_cells) * px - pit_w * 0.5
	var straight_start : Vector2 = Vector2(center.x - hs, pit_y)
	var straight_end : Vector2 = Vector2(center.x + hs, pit_y)

	# Branch points on the INNER lane of the track
	var inner_lane_radius : float = radius - half_track + lane_w * 0.5
	var entry_point : Vector2 = center + Vector2(-hs, 0.0) \
			+ Vector2.from_angle(PI * 0.5 + ramp) * inner_lane_radius
	var exit_point : Vector2 = center + Vector2(hs, 0.0) \
			+ Vector2.from_angle(PI * 0.5 - ramp) * inner_lane_radius
	var entry_dir : Vector2 = _data.track_forward_at(entry_point)
	var exit_dir : Vector2 = _data.track_forward_at(exit_point)
	var entry_handle : float = entry_point.distance_to(straight_start) * 0.4
	var exit_handle : float = straight_end.distance_to(exit_point) * 0.4

	# Tangent to the track at both branch points: the car peels off and merges
	# back without a kink
	var curve : Curve2D = Curve2D.new()
	curve.add_point(entry_point, Vector2.ZERO, entry_dir * entry_handle)
	curve.add_point(straight_start, Vector2.LEFT * entry_handle, Vector2.ZERO)
	curve.add_point(straight_end, Vector2.ZERO, Vector2.RIGHT * exit_handle)
	curve.add_point(exit_point, -exit_dir * exit_handle, Vector2.ZERO)
	_data.pit_curve = curve
	_data.pit_width_px = int(pit_w)
	_rasterize_pit(curve, pit_w * 0.5)


func _rasterize_pit(curve : Curve2D, half_width : float) -> void:
	# Distance to the baked pit centreline, scanned over its bounding box only
	var px : float = float(cell_size)
	var w : int = map_size_cells.x
	var box : Rect2 = Rect2(curve.get_point_position(0), Vector2.ZERO)
	for point : Vector2 in curve.get_baked_points():
		box = box.expand(point)
	box = box.grow(half_width + px)
	var first_x : int = maxi(int(floor(box.position.x / px)), 0)
	var first_y : int = maxi(int(floor(box.position.y / px)), 0)
	var last_x : int = mini(int(ceil(box.end.x / px)), map_size_cells.x)
	var last_y : int = mini(int(ceil(box.end.y / px)), map_size_cells.y)

	var min_cell : Vector2i = map_size_cells
	var max_cell : Vector2i = Vector2i(-1, -1)
	for y : int in range(first_y, last_y):
		for x : int in range(first_x, last_x):
			var index : int = y * w + x
			# Where the ramps overlap the racing surface, the track wins
			if _data.cells[index] == MapData.CellType.ARTERY:
				continue
			var p : Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5)) * px
			if p.distance_to(curve.get_closest_point(p)) > half_width:
				continue
			_data.cells[index] = MapData.CellType.PIT
			min_cell = Vector2i(mini(min_cell.x, x), mini(min_cell.y, y))
			max_cell = Vector2i(maxi(max_cell.x, x), maxi(max_cell.y, y))

	# Bounding box of the PIT cells: get_pit_cells() and the sidewalk pass scan it
	if max_cell.x >= 0:
		_data.pit_rect = Rect2i(min_cell, max_cell - min_cell + Vector2i.ONE)
	else:
		_data.pit_rect = Rect2i()


func _reset_blocks() -> void:
	# No flood fill on an oval: the belt pass only probes the map border, and
	# nothing is ever built on the infield.
	var total : int = map_size_cells.x * map_size_cells.y
	_data.cell_block_id = PackedInt32Array()
	_data.cell_block_id.resize(total)
	_data.cell_block_id.fill(-1)
	_data.block_rects = [] as Array[Rect2i]
	_data.block_areas = [] as Array[int]
	_data.district_plot = Rect2i()
	_data.district_block_id = -1


# =================================================================
# GEOMETRY HELPERS
# =================================================================
func _turn_center(side : int) -> Vector2:
	var px : float = float(cell_size)
	return Vector2(map_size_cells) * 0.5 * px \
			+ Vector2(float(side) * float(straight_cells) * 0.5 * px, 0.0)


func _distance_to_segment(p : Vector2, a : Vector2, b : Vector2) -> float:
	var ab : Vector2 = b - a
	var t : float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)
