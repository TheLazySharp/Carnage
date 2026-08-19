class_name MapBuildingsPlacer
extends Node2D
## Building placement pass. Order matters:
##   1. district plot   : the mandatory building of the current district, alone
##                        in its reserved block
##   2. belt            : corners, then the four sides paved with peripherals
##                        and fillers, sidewalk face always looking at the city
##   3. block interiors : greedy largest-first fill of every remaining block
## Then MapData.finalize_sidewalks() turns whatever is left into pavement,
## ready for a single set_cells_terrain_connect() call.

@export var pool : BuildingPool = null
## District of the current run; N_A places no district building
@export var district_type : DistrictsData.types = DistrictsData.types.N_A
## Depth of the belt buildings, in cells (they all share it by design)
@export var belt_depth_cells : int = 4
## Cells left between two interior buildings. 0 = contiguous city block.
@export var building_gap_cells : int = 0
## Turn every remaining FREE cell into SIDEWALK once placement is done
@export var finalize_sidewalks : bool = true

## Footprint cells of every placed building: feed this to the flow field
## (FlowFieldManager.add_obstacles) and to the horde wall grid.
var obstacle_cells : Array[Vector2i] = []

var _data : MapData = null
var _rng : RandomNumberGenerator = RandomNumberGenerator.new()
var _placed : int = 0


func build(data : MapData) -> void:
	for child : Node in get_children():
		child.queue_free()
	obstacle_cells.clear()
	_placed = 0

	if pool == null:
		push_error("[MapBuildingsPlacer] no BuildingPool assigned")
		return

	_data = data
	_rng.seed = data.seed_used ^ 0x5EED  # own stream: adding a pass upstream
										 # must not shift the building layout

	if not _check_setup():
		return

	_place_district_building()
	_place_belt()
	_fill_blocks()

	if finalize_sidewalks:
		_data.finalize_sidewalks()

	print("[MapBuildingsPlacer] placed ", _placed, " buildings")


## Fails fast with an explicit message instead of a silent empty result
func _check_setup() -> bool:
	for required : String in ["district_plot", "district_block_id", "cell_block_id"]:
		if not required in _data:
			push_error("[MapBuildingsPlacer] MapData has no '%s': the DISTRICT PLOT / BLOCKS blocks are missing from map_data.gd" % required)
			return false
	for method : String in ["can_place_building", "mark_building", "finalize_sidewalks"]:
		if not _data.has_method(method):
			push_error("[MapBuildingsPlacer] MapData has no %s(): the BUILDINGS / SIDEWALKS block is missing from map_data.gd" % method)
			return false

	print("[MapBuildingsPlacer] pool '%s': %d interiors, %d peripherals, %d corners, %d fillers, %d district | blocks: %d | district plot: %s (block %d)" % [
		GameMaster.BIOMES.keys()[pool.biome],
		pool.interiors.size(), pool.peripherals.size(), pool.corners.size(),
		pool.fillers.size(), pool.district_buildings.size(),
		_data.block_rects.size(), str(_data.district_plot.size), _data.district_block_id])

	var usable : int = 0
	for entry : BuildingData in pool.interiors:
		if entry != null and entry.building_scene != null and entry.biome == pool.biome and not entry.is_district_specific():
			usable += 1
	if usable == 0 and not pool.interiors.is_empty():
		push_warning("[MapBuildingsPlacer] no usable interior: check that each BuildingData has a scene, the pool's biome, and district_type = N_A")
	return true


# =================================================================
# 1 : DISTRICT BUILDING
# =================================================================
func _place_district_building() -> void:
	if _data.district_block_id == -1:
		return
	var entry : Dictionary = pool.pick_district_building(district_type, _rng)
	if entry.is_empty():
		return  # this district needs no specific building

	var data : BuildingData = entry["data"]
	var plot : Rect2i = _data.district_plot
	if data.footprint_32.x > plot.size.x or data.footprint_32.y > plot.size.y:
		push_warning("[MapBuildingsPlacer] '%s' (%s) does not fit the %s district plot" % [
			data.name, str(data.footprint_32), str(plot.size)])
		return

	# Centered in the reserved plot, so it ends up surrounded by pavement
	@warning_ignore("integer_division")
	var origin : Vector2i = plot.position + (plot.size - data.footprint_32) / 2
	var rect : Rect2i = Rect2i(origin, data.footprint_32)
	if not _data.can_place_building(rect):
		push_warning("[MapBuildingsPlacer] district plot is not free")
		return
	if not _interaction_circle_fits(rect, data.circle_margin):
		push_warning("[MapBuildingsPlacer] '%s' interaction circle does not fit the map" % data.name)
	_place(data, rect, 0)


## The building's interaction circle must stay inside the map, or the player
## could never trigger it from every side (rule inherited from BuildingSpawner)
func _interaction_circle_fits(rect : Rect2i, margin : float) -> bool:
	var cell : float = float(_data.cell_size)
	var center : Vector2 = (Vector2(rect.position) + Vector2(rect.size) * 0.5) * cell
	var radius : float = maxf(float(rect.size.x), float(rect.size.y)) * cell * 0.5 + margin
	var map_px : Vector2 = Vector2(_data.map_size_cells) * cell
	return center.x - radius >= 0.0 and center.y - radius >= 0.0 \
		and center.x + radius <= map_px.x and center.y + radius <= map_px.y


# =================================================================
# 2 : BELT
# =================================================================
func _place_belt() -> void:
	if pool.peripherals.is_empty():
		print("[MapBuildingsPlacer] no peripheral building in the pool: belt skipped")
		return

	_place_belt_corners()
	# Sides are paved between the corners; the entry / extraction mouths are
	# skipped for free, since their cells are not FREE in the raster.
	_pave_side(BuildingData.Side.TOP)
	_pave_side(BuildingData.Side.BOTTOM)
	_pave_side(BuildingData.Side.LEFT)
	_pave_side(BuildingData.Side.RIGHT)


func _place_belt_corners() -> void:
	if pool.corners.is_empty():
		return
	var w : int = _data.map_size_cells.x
	var h : int = _data.map_size_cells.y
	for corner : int in 4:
		var entry : Dictionary = pool.pick_corner(Vector2i(belt_depth_cells, belt_depth_cells), _rng)
		if entry.is_empty():
			return
		var data : BuildingData = entry["data"]
		var turns : int = BuildingData.quarter_turns_for_corner(corner)
		var size : Vector2i = BuildingData.rotated_size(data.footprint_32, turns)
		var origin : Vector2i = Vector2i.ZERO
		match corner:
			BuildingData.Corner.TOP_LEFT:
				origin = Vector2i.ZERO
			BuildingData.Corner.TOP_RIGHT:
				origin = Vector2i(w - size.x, 0)
			BuildingData.Corner.BOTTOM_RIGHT:
				origin = Vector2i(w - size.x, h - size.y)
			_:
				origin = Vector2i(0, h - size.y)
		var rect : Rect2i = Rect2i(origin, size)
		if _data.can_place_building(rect):
			_place(data, rect, turns)


func _pave_side(side : int) -> void:
	# Walks the side and places the widest piece that fits at each step.
	# Anything that cannot be filled stays FREE and becomes sidewalk.
	var turns : int = BuildingData.quarter_turns_for_side(side)
	var length : int = _data.map_size_cells.x if (side == BuildingData.Side.TOP or side == BuildingData.Side.BOTTOM) else _data.map_size_cells.y
	var cursor : int = 0
	var unpaved : int = 0

	while cursor < length:
		var free_run : int = _free_run(side, cursor, length)
		if free_run <= 0:
			cursor += 1
			continue

		var entry : Dictionary = pool.pick_peripheral(free_run, belt_depth_cells, _rng)
		if entry.is_empty():
			entry = pool.pick_filler(free_run, belt_depth_cells, _rng)
		if entry.is_empty():
			# Nothing fits this gap: leave it as pavement and move on
			unpaved += free_run
			cursor += free_run
			continue

		var data : BuildingData = entry["data"]
		var rect : Rect2i = _side_rect(side, cursor, data.footprint_32.x, data.footprint_32.y)
		if _data.can_place_building(rect):
			_place(data, rect, turns)
			cursor += data.footprint_32.x
		else:
			cursor += 1

	if unpaved > 0:
		print("[MapBuildingsPlacer] %s belt: %d cells left unpaved (add narrower fillers to close them)" % [
			BuildingData.Side.keys()[side], unpaved])


func _free_run(side : int, cursor : int, length : int) -> int:
	# Number of consecutive positions from cursor where a full-depth piece fits
	var run : int = 0
	while cursor + run < length and _data.can_place_building(_side_rect(side, cursor + run, 1, belt_depth_cells)):
		run += 1
	return run


func _side_rect(side : int, cursor : int, width : int, depth : int) -> Rect2i:
	# Rect occupied on the map by a piece of `width` along the side and
	# `depth` toward the city, placed at `cursor`
	var w : int = _data.map_size_cells.x
	var h : int = _data.map_size_cells.y
	match side:
		BuildingData.Side.TOP:
			return Rect2i(cursor, 0, width, depth)
		BuildingData.Side.BOTTOM:
			return Rect2i(cursor, h - depth, width, depth)
		BuildingData.Side.LEFT:
			return Rect2i(0, cursor, depth, width)
		_:  # RIGHT
			return Rect2i(w - depth, cursor, depth, width)


# =================================================================
# 3 : BLOCK INTERIORS
# =================================================================
func _fill_blocks() -> void:
	if pool.interiors.is_empty():
		print("[MapBuildingsPlacer] no interior building in the pool: blocks left empty")
		return

	var w : int = _data.map_size_cells.x
	var h : int = _data.map_size_cells.y
	for y : int in h:
		for x : int in w:
			var idx : int = y * w + x
			if _data.cells[idx] != MapData.CellType.FREE:
				continue
			var block_id : int = _data.cell_block_id[idx]
			if block_id == _data.district_block_id:
				continue  # reserved: the district building stays alone there
			if block_id == -1:
				continue  # belt leftovers, handled by the belt pass

			# Largest free rectangle anchored at this cell
			var max_size : Vector2i = _max_free_rect(x, y, block_id)
			if max_size.x <= 0 or max_size.y <= 0:
				continue
			var entry : Dictionary = pool.pick_interior(max_size, _rng)
			if entry.is_empty():
				continue

			var data : BuildingData = entry["data"]
			var turns : int = entry["quarter_turns"]
			var size : Vector2i = BuildingData.rotated_size(data.footprint_32, turns)
			var rect : Rect2i = Rect2i(Vector2i(x, y), size)
			if _data.can_place_building(rect):
				_place(data, rect, turns)
				if building_gap_cells > 0:
					_reserve_gap(rect)


func _max_free_rect(start_x : int, start_y : int, block_id : int) -> Vector2i:
	# Staircase scan: for each height, the width is the running minimum of the
	# free runs. Keeps the rectangle with the biggest area.
	var w : int = _data.map_size_cells.x
	var h : int = _data.map_size_cells.y
	var best : Vector2i = Vector2i.ZERO
	var best_area : int = 0
	var current_w : int = 1 << 30

	for dy : int in range(0, h - start_y):
		var run : int = 0
		while start_x + run < w and _is_buildable(start_x + run, start_y + dy, block_id):
			run += 1
		if run == 0:
			break
		current_w = mini(current_w, run)
		var area : int = current_w * (dy + 1)
		if area > best_area:
			best_area = area
			best = Vector2i(current_w, dy + 1)
	return best


func _is_buildable(x : int, y : int, block_id : int) -> bool:
	var idx : int = y * _data.map_size_cells.x + x
	return _data.cells[idx] == MapData.CellType.FREE and _data.cell_block_id[idx] == block_id


func _reserve_gap(rect : Rect2i) -> void:
	# Marks a pavement strip around the building so the next ones keep away.
	# Cells stay non-FREE, hence excluded from further placement, and
	# finalize_sidewalks() will turn them into sidewalk anyway.
	var g : int = building_gap_cells
	var area : Rect2i = Rect2i(rect.position - Vector2i(g, g), rect.size + Vector2i(g, g) * 2)
	for y : int in range(maxi(area.position.y, 0), mini(area.end.y, _data.map_size_cells.y)):
		var row : int = y * _data.map_size_cells.x
		for x : int in range(maxi(area.position.x, 0), mini(area.end.x, _data.map_size_cells.x)):
			if _data.cells[row + x] == MapData.CellType.FREE:
				_data.cells[row + x] = MapData.CellType.SIDEWALK


# =================================================================
# SPAWN
# =================================================================
func _place(data : BuildingData, rect : Rect2i, quarter_turns : int) -> void:
	var instance : Node2D = data.building_scene.instantiate() as Node2D
	if instance == null:
		push_error("[MapBuildingsPlacer] '%s' scene root must be a Node2D" % data.name)
		return

	var cell : int = _data.cell_size
	# The scene origin is its top-left corner; rotating around that origin
	# moves the content, rotation_offset() puts it back on the rect
	instance.position = Vector2(rect.position) * float(cell) \
		+ BuildingData.rotation_offset(data.footprint_32, quarter_turns, cell)
	instance.rotation = float(quarter_turns) * PI * 0.5
	if "building_data" in instance:
		instance.set("building_data", data)
	add_child(instance)

	_data.mark_building(rect)
	for y : int in range(rect.position.y, rect.end.y):
		for x : int in range(rect.position.x, rect.end.x):
			obstacle_cells.append(Vector2i(x, y))
	_placed += 1
