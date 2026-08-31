class_name MapGenerator
extends RefCounted
## Builds a MapData in three passes:
##   1. road graph  : perturbed grid, arteries, street removal (no dead end,
##                    fully connected), entry/extraction openings
##   2. cell grid   : roads + sidewalks rasterized into map_size_cells cells
##   3. blocks      : flood fill of the FREE cells -> buildable islands
## Configure the parameters below, then call generate().

# ---------------- MAP PARAMETERS ----------------
var map_size_cells : Vector2i = Vector2i(96, 80)
var cell_size : int = 32                        # px
var lane_width_px : int = 96                    # one road lane = 3 cells
var street_lanes : int = 2                      # standard road: 2 x 1 lane -> 6 cells
var artery_lanes : int = 4                      # artery: 2 x 2 lanes -> 12 cells

# ---------------- GRAPH PARAMETERS ----------------
var border_margin_cells : int = 6               # distance between the closed border and the outer sidewalks
var block_interior_min : int = 4                # min buildable cells between two sidewalks (fits a 4x4)
var block_interior_max : int = 12               # max buildable cells between two sidewalks
var removal_ratio : float = 0.1                 # fraction of street edges we try to remove
var artery_count_h : int = 1                    # horizontal arteries (min 1: the entry->extraction one)
var artery_count_v : int = 1                    # vertical arteries
var sidewalk_cells : int = 2                    # drivable sidewalk band on each side of every road

# ---------------- INTERNAL STATE ----------------
var _data : MapData = null
var _rng : RandomNumberGenerator = null

var reserve_district_plot : bool = true
var district_plot_size : Vector2i = Vector2i(6, 6)

func generate(map_seed : int = 0) -> MapData:
	# map_seed = 0 -> random seed; the used seed is stored in MapData.seed_used
	_rng = RandomNumberGenerator.new()
	var used_seed : int = map_seed if map_seed != 0 else int(Time.get_unix_time_from_system()) ^ randi()
	_rng.seed = used_seed

	_data = MapData.new()
	_data.seed_used = used_seed
	_data.map_size_cells = map_size_cells
	_data.cell_size = cell_size
	_data.lane_width_px = lane_width_px
	_data.street_lanes = street_lanes
	_data.artery_lanes = artery_lanes
	_data.sidewalk_cells = sidewalk_cells
	
	_build_graph()
	_rasterize_cells()
	_extract_blocks()
	_reserve_district_plot()
	return _data


# =================================================================
# PASS 1 : ROAD GRAPH
# =================================================================
func _build_graph() -> void:
	# Road axes. Spacing is computed from BLOCK INTERIORS (buildable cells
	# between sidewalks), so every block can hold at least a 4x4 building.
	var cols_data : Dictionary = _build_axes(map_size_cells.x, maxi(0, artery_count_v), district_plot_size.x, true)
	var rows_data : Dictionary = _build_axes(map_size_cells.y, maxi(1, artery_count_h), district_plot_size.y, false)
	var cols : PackedInt32Array = cols_data["positions"]
	var col_is_artery : Array[bool] = cols_data["artery"]
	var rows : PackedInt32Array = rows_data["positions"]
	var row_is_artery : Array[bool] = rows_data["artery"]
	var n_cols : int = cols.size()

	# Main artery = the artery row closest to mid-height (entry/exit align on it)
	var artery_row : int = -1
	var best_dist : int = 1 << 30
	for r : int in rows.size():
		if not row_is_artery[r]:
			continue
		var d : int = absi(rows[r] - map_size_cells.y / 2)
		if d < best_dist:
			best_dist = d
			artery_row = r
	_data.artery_y = rows[artery_row]

	# Grid nodes
	for r : int in rows.size():
		for c : int in n_cols:
			_data.nodes.append(Vector2(float(cols[c]), float(rows[r])))

	# Grid edges (horizontal + vertical neighbours)
	for r : int in rows.size():
		for c : int in n_cols:
			var idx : int = r * n_cols + c
			if c < n_cols - 1:
				_data.edges.append(Vector2i(idx, idx + 1))
				_data.edge_is_artery.append(row_is_artery[r])
			if r < rows.size() - 1:
				_data.edges.append(Vector2i(idx, idx + n_cols))
				_data.edge_is_artery.append(col_is_artery[c])

	# Random street removal (never an artery), keeping:
	# - every node at degree >= 2 -> no dead end
	# - the graph fully connected  -> everything reachable
	_remove_random_edges()

	# Entry (left) / extraction (right) openings, plugged on the main artery.
	# These two nodes are the only degree-1 nodes: they are the run's doors.
	_data.entry_node_idx = _data.nodes.size()
	_data.nodes.append(Vector2(0.0, float(_data.artery_y)))
	_data.edges.append(Vector2i(_data.entry_node_idx, artery_row * n_cols))
	_data.edge_is_artery.append(true)

	_data.exit_node_idx = _data.nodes.size()
	_data.nodes.append(Vector2(float(map_size_cells.x), float(_data.artery_y)))
	_data.edges.append(Vector2i(_data.exit_node_idx, artery_row * n_cols + n_cols - 1))
	_data.edge_is_artery.append(true)


func _street_w() -> int:
	@warning_ignore("integer_division")
	return street_lanes * lane_width_px / cell_size  # assumes lane width multiple of cell_size


func _artery_w() -> int:
	@warning_ignore("integer_division")
	return artery_lanes * lane_width_px / cell_size


func _build_axes(map_extent : int, artery_count : int, guarantee_gap : int = 0, guarantee_second_half : bool = false) -> Dictionary:
	# Places road axes along one direction, widths included, so that every gap
	# between two sidewalks is a buildable interior in [interior_min, interior_max].
	# Returns {"positions": PackedInt32Array (centerlines), "artery": Array[bool]}.
	var span : int = map_extent - 2 * border_margin_cells
	var gap_min : int = block_interior_min + 2 * sidewalk_cells

	# Max number of axes fitting the span with minimal interiors
	var count : int = maxi(artery_count, 2)
	while _axes_min_width(count + 1, artery_count, gap_min) <= span:
		count += 1

	# Random artery slots among the axes
	var flags : Array[bool] = []
	flags.resize(count)
	flags.fill(false)

	# Random artery slots among the axes. The first and last axes are excluded:
	# an artery on the outer ring turns into a street at the grid corners, which
	# is the same mixed-width bend the removal pass now forbids.
	var slots : Array[int] = []
	for i : int in count:
		if i == 0 or i == count - 1:
			continue
		slots.append(i)
	if slots.is_empty():
		for i : int in count:
			slots.append(i)
	_shuffle(slots)
	for i : int in mini(artery_count, slots.size()):
		flags[slots[i]] = true

	# Interiors: minimum everywhere, then spread the leftover span at random
	var interiors : PackedInt32Array = PackedInt32Array()
	interiors.resize(count - 1)
	interiors.fill(block_interior_min)
	var slack : int = span - _axes_min_width(count, artery_count, gap_min)
	var order : Array[int] = []
	for i : int in count - 1:
		order.append(i)
	_shuffle(order)
	
	# Guarantee one gap large enough for the district plot, in the second half
	# of the axis (right / bottom side of the map)
	if guarantee_gap > block_interior_min and interiors.size() > 0:
		@warning_ignore("integer_division")
		var first : int = interiors.size() / 2 if guarantee_second_half else 0
		var idx : int = _rng.randi_range(first, interiors.size() - 1)
		var need : int = mini(guarantee_gap, block_interior_max) - interiors[idx]
		if need > 0 and slack >= need:
			interiors[idx] += need
			slack -= need
	
	
	var max_extra : int = block_interior_max - block_interior_min
	for g : int in order:
		if slack <= 0:
			break
		var extra : int = _rng.randi_range(0, mini(slack, max_extra))
		interiors[g] += extra
		slack -= extra

	# Centerline positions, painted band centered inside the margins
	var painted : int = 2 * sidewalk_cells
	for i : int in count:
		painted += _artery_w() if flags[i] else _street_w()
	for g : int in interiors.size():
		painted += interiors[g] + 2 * sidewalk_cells

	var positions : PackedInt32Array = PackedInt32Array()
	positions.resize(count)
	@warning_ignore("integer_division")
	var cursor : int = border_margin_cells + (span - painted) / 2 + sidewalk_cells
	for i : int in count:
		var w : int = _artery_w() if flags[i] else _street_w()
		@warning_ignore("integer_division")
		positions[i] = cursor + w / 2
		cursor += w
		if i < count - 1:
			cursor += sidewalk_cells + interiors[i] + sidewalk_cells

	return {"positions": positions, "artery": flags}


func _axes_min_width(count : int, artery_count : int, gap_min : int) -> int:
	# Painted width (roads + sidewalks + minimal interiors) for `count` axes
	var n_artery : int = mini(artery_count, count)
	var roads : int = n_artery * _artery_w() + (count - n_artery) * _street_w()
	return roads + (count - 1) * gap_min + 2 * sidewalk_cells


func _shuffle(values : Array[int]) -> void:
	# Fisher-Yates with the seeded rng (Array.shuffle() uses the global RNG
	# and would break seed determinism)
	for i : int in range(values.size() - 1, 0, -1):
		var j : int = _rng.randi_range(0, i)
		var tmp : int = values[i]
		values[i] = values[j]
		values[j] = tmp


func _remove_random_edges() -> void:
	var degrees : PackedInt32Array = PackedInt32Array()
	degrees.resize(_data.nodes.size())
	for e : Vector2i in _data.edges:
		degrees[e.x] += 1
		degrees[e.y] += 1

	# Candidates = street edges only
	var candidates : Array[int] = []
	for i : int in _data.edges.size():
		if not _data.edge_is_artery[i]:
			candidates.append(i)
	_shuffle(candidates)

	var target : int = int(removal_ratio * float(candidates.size()))
	var removed : Array[bool] = []
	removed.resize(_data.edges.size())
	removed.fill(false)

	var removed_count : int = 0
	for edge_idx : int in candidates:
		if removed_count >= target:
			break
		var e : Vector2i = _data.edges[edge_idx]
		if degrees[e.x] <= 2 or degrees[e.y] <= 2:
			continue  # removing it would create a dead end
		if _would_mix_road_types(e.x, removed, edge_idx) or _would_mix_road_types(e.y, removed, edge_idx):
			continue  # an artery must never bend into a street
		removed[edge_idx] = true
		if _is_graph_connected(removed):
			degrees[e.x] -= 1
			degrees[e.y] -= 1
			removed_count += 1
		else:
			removed[edge_idx] = false  # rollback: it would split the map

	# Compact the edge arrays
	var kept_edges : Array[Vector2i] = []
	var kept_flags : Array[bool] = []
	for i : int in _data.edges.size():
		if not removed[i]:
			kept_edges.append(_data.edges[i])
			kept_flags.append(_data.edge_is_artery[i])
	_data.edges = kept_edges
	_data.edge_is_artery = kept_flags

func _would_mix_road_types(node_idx : int, removed : Array[bool], removing : int) -> bool:
	# True when the node would end up at degree 2 with one artery branch and one
	# street branch. That is a bend where the road changes width mid-corner:
	# the marking chains cannot follow through it (different types), so they stop
	# dead at the node centre, and the arrow pass reads it as an approach.
	var artery_seen : bool = false
	var street_seen : bool = false
	var kept : int = 0
	for i : int in _data.edges.size():
		if removed[i] or i == removing:
			continue
		var e : Vector2i = _data.edges[i]
		if e.x != node_idx and e.y != node_idx:
			continue
		kept += 1
		if _data.edge_is_artery[i]:
			artery_seen = true
		else:
			street_seen = true
	return kept == 2 and artery_seen and street_seen

func _is_graph_connected(removed : Array[bool]) -> bool:
	# DFS with a linear edge scan per node: O(V * E). Fine at this graph size;
	# swap for an adjacency list if the map grows significantly.
	var count : int = _data.nodes.size()
	if count == 0:
		return true
	var visited : Array[bool] = []
	visited.resize(count)
	visited.fill(false)
	var stack : Array[int] = [0]
	visited[0] = true
	var seen : int = 1
	while not stack.is_empty():
		var current : int = stack.pop_back()
		for i : int in _data.edges.size():
			if removed[i]:
				continue
			var e : Vector2i = _data.edges[i]
			var other : int = -1
			if e.x == current:
				other = e.y
			elif e.y == current:
				other = e.x
			else:
				continue
			if not visited[other]:
				visited[other] = true
				seen += 1
				stack.append(other)
	return seen == count


# =================================================================
# PASS 2 : CELL GRID (rasterization)
# =================================================================
func _rasterize_cells() -> void:
	_data.cells = PackedByteArray()
	_data.cells.resize(map_size_cells.x * map_size_cells.y)  # 0 = FREE

	# Roads: one band per edge...
	for i : int in _data.edges.size():
		var road_type : int = MapData.CellType.ARTERY if _data.edge_is_artery[i] else MapData.CellType.STREET
		_mark_edge_band(_data.edges[i], _edge_width(i), 0, road_type)
	# ...plus one square per node so corners are covered at intersections
	var node_widths : PackedInt32Array = _node_widths()
	for i : int in _data.nodes.size():
		var node_type : int = MapData.CellType.ARTERY if node_widths[i] == _artery_w() else MapData.CellType.STREET
		_mark_node_square(i, node_widths[i], 0, node_type)

	# Sidewalks: same shapes expanded, only over FREE cells
	for i : int in _data.edges.size():
		_mark_edge_band(_data.edges[i], _edge_width(i), sidewalk_cells, MapData.CellType.SIDEWALK)
	for i : int in _data.nodes.size():
		_mark_node_square(i, node_widths[i], sidewalk_cells, MapData.CellType.SIDEWALK)


func _edge_width(edge_idx : int) -> int:
	return _artery_w() if _data.edge_is_artery[edge_idx] else _street_w()


func _node_widths() -> PackedInt32Array:
	# Widest incident road per node
	var widths : PackedInt32Array = PackedInt32Array()
	widths.resize(_data.nodes.size())
	for i : int in _data.edges.size():
		var w : int = _edge_width(i)
		widths[_data.edges[i].x] = maxi(widths[_data.edges[i].x], w)
		widths[_data.edges[i].y] = maxi(widths[_data.edges[i].y], w)
	return widths


func _mark_edge_band(edge : Vector2i, road_width : int, expand : int, type : int) -> void:
	# Axis-aligned band centered on the edge, `expand` extra cells on every side
	var a : Vector2i = Vector2i(_data.nodes[edge.x])
	var b : Vector2i = Vector2i(_data.nodes[edge.y])
	@warning_ignore("integer_division")
	var half : int = road_width / 2
	if a.y == b.y:  # horizontal
		var x0 : int = mini(a.x, b.x) - expand
		var x1 : int = maxi(a.x, b.x) + expand - 1
		_mark_rect(x0, a.y - half - expand, x1, a.y + half - 1 + expand, type)
	else:  # vertical
		var y0 : int = mini(a.y, b.y) - expand
		var y1 : int = maxi(a.y, b.y) + expand - 1
		_mark_rect(a.x - half - expand, y0, a.x + half - 1 + expand, y1, type)


func _mark_node_square(node_idx : int, road_width : int, expand : int, type : int) -> void:
	var p : Vector2i = Vector2i(_data.nodes[node_idx])
	@warning_ignore("integer_division")
	var half : int = road_width / 2
	_mark_rect(p.x - half - expand, p.y - half - expand, p.x + half - 1 + expand, p.y + half - 1 + expand, type)


func _mark_rect(x0 : int, y0 : int, x1 : int, y1 : int, type : int) -> void:
	# Marks the inclusive cell rect, clamped to the map.
	# Roads overwrite everything except ARTERY over STREET priority;
	# SIDEWALK only fills FREE cells.
	var w : int = map_size_cells.x
	x0 = maxi(x0, 0)
	y0 = maxi(y0, 0)
	x1 = mini(x1, map_size_cells.x - 1)
	y1 = mini(y1, map_size_cells.y - 1)
	var sidewalk : bool = type == MapData.CellType.SIDEWALK
	for y : int in range(y0, y1 + 1):
		var row : int = y * w
		for x : int in range(x0, x1 + 1):
			var idx : int = row + x
			var current : int = _data.cells[idx]
			if sidewalk:
				if current == MapData.CellType.FREE:
					_data.cells[idx] = type
			elif not (current == MapData.CellType.ARTERY and type == MapData.CellType.STREET):
				_data.cells[idx] = type


# =================================================================
# PASS 3 : BLOCKS (flood fill of FREE cells)
# =================================================================
func _extract_blocks() -> void:
	var w : int = map_size_cells.x
	var h : int = map_size_cells.y
	_data.cell_block_id = PackedInt32Array()
	_data.cell_block_id.resize(w * h)
	_data.cell_block_id.fill(-1)
	_data.block_rects = []
	_data.block_areas = PackedInt32Array()

	var stack : Array[int] = []
	for start : int in w * h:
		if _data.cells[start] != MapData.CellType.FREE or _data.cell_block_id[start] != -1:
			continue
		var id : int = _data.block_rects.size()
		var min_x : int = w
		var min_y : int = h
		var max_x : int = 0
		var max_y : int = 0
		var area : int = 0
		stack.clear()
		stack.append(start)
		_data.cell_block_id[start] = id
		while not stack.is_empty():
			var idx : int = stack.pop_back()
			var x : int = idx % w
			@warning_ignore("integer_division")
			var y : int = idx / w
			area += 1
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
			# 4-connectivity
			if x > 0:
				_try_fill(idx - 1, id, stack)
			if x < w - 1:
				_try_fill(idx + 1, id, stack)
			if y > 0:
				_try_fill(idx - w, id, stack)
			if y < h - 1:
				_try_fill(idx + w, id, stack)
		_data.block_rects.append(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))
		_data.block_areas.append(area)


func _try_fill(idx : int, id : int, stack : Array[int]) -> void:
	if _data.cells[idx] == MapData.CellType.FREE and _data.cell_block_id[idx] == -1:
		_data.cell_block_id[idx] = id
		stack.append(idx)


# =================================================================
# PASS 4 : DISTRICT PLOT
# =================================================================
func _reserve_district_plot() -> void:
	_data.district_plot = Rect2i()
	_data.district_block_id = -1
	if not reserve_district_plot:
		return
	# Right half first (closest to the extraction), whole map as a fallback
	if not _try_reserve_plot(true):
		_try_reserve_plot(false)
	if _data.district_block_id == -1:
		push_warning("[MapGenerator] no block can host the %s district plot" % str(district_plot_size))


func _try_reserve_plot(right_half_only : bool) -> bool:
	var exit_point : Vector2 = Vector2(float(map_size_cells.x), float(_data.artery_y))
	@warning_ignore("integer_division")
	var half_x : int = map_size_cells.x / 2
	var best_score : float = INF

	for id : int in _data.block_rects.size():
		var r : Rect2i = _data.block_rects[id]
		if r.size.x < district_plot_size.x or r.size.y < district_plot_size.y:
			continue
		var center : Vector2 = Vector2(r.position) + Vector2(r.size) * 0.5
		if right_half_only and center.x < float(half_x):
			continue
		# Centered in its block: the building ends up surrounded by pavement
		@warning_ignore("integer_division")
		var origin : Vector2i = r.position + (r.size - district_plot_size) / 2
		var plot : Rect2i = Rect2i(origin, district_plot_size)
		if not _data.can_place_building(plot):
			continue  # L-shaped block: the centered plot would overlap a road
		var score : float = center.distance_to(exit_point)
		if score < best_score:
			best_score = score
			_data.district_plot = plot
			_data.district_block_id = id

	return _data.district_block_id != -1
