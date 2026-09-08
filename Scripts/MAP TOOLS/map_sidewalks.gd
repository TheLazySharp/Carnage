class_name MapSidewalks
extends Node2D
## The set is painted in ONE call PER BLOCK, so each island can carry its own
## style. Two blocks are always separated by a road, so their sidewalk regions
## never touch and each group resolves its corner joints on its own. Painting
## two TOUCHING groups separately would produce a seam.

@export var layer : TileMapLayer = null
@export var terrain_set : int = 0
## Available sidewalk styles inside that terrain set. One is drawn per map.
@export var terrains : Array[int] = [0]

# ---------------- PROPS ----------------
@export_group("Props")
## Flat decals scattered on the pavement (manholes, drains, grates...).
## One sliced .tres per prop, as delivered by the artist.
@export var prop_textures : Array[Texture2D] = []
## Where the sprites are parented (e.g. Lands/RoadProps). Defaults to this node.
@export var props_parent : Node2D = null
@export_range(0.0, 0.2, 0.001) var prop_chance : float = 0.01
## Minimum distance between two props, in cells
@export var prop_min_distance : int = 4
## Random offset inside the cell, in pixels, to break the grid
@export var prop_jitter_px : float = 8.0
## Flat decals cast no shadow, so quarter turns are free variation
@export var random_quarter_turns : bool = true

var _props_root : Node2D = null


func build(data : MapData) -> void:
	if layer == null:
		push_error("[MapSidewalks] no TileMapLayer assigned")
		return
	if terrains.is_empty():
		push_error("[MapSidewalks] terrains is empty")
		return

	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = data.seed_used ^ 0x51DE  # own stream

	layer.clear()
	var cells : Array[Vector2i] = data.get_sidewalk_cells()
	if cells.is_empty():
		push_warning("[MapSidewalks] no sidewalk cell: did the placer run finalize_sidewalks()?")
		return

	# One style per CONTIGUOUS sidewalk region, not per block: cell_block_id is
	# only set on the buildable interior, so grouping by it splits every island
	# into a band and a core, and each half gets painted with its own border.
	# A flood fill matches what the eye reads as one pavement.
	var regions : Array[Array] = _flood_regions(cells)
	for region : Array in regions:
		var group : Array[Vector2i] = []
		group.assign(region)
		var terrain : int = terrains[rng.randi_range(0, terrains.size() - 1)]
		layer.set_cells_terrain_connect(group, terrain_set, terrain, false)

	print("[MapSidewalks] painted ", cells.size(), " cells over ", regions.size(), " regions")

	_scatter_props(data, cells, rng)

func _flood_regions(cells : Array[Vector2i]) -> Array[Array]:
	# 4-connected flood fill over the sidewalk cells. Roads cut the pavement, so
	# each island comes out as exactly one region, band and interior together.
	const NEIGHBOURS : Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	var in_set : Dictionary = {}
	for cell : Vector2i in cells:
		in_set[cell] = true

	var visited : Dictionary = {}
	var regions : Array[Array] = []
	for cell : Vector2i in cells:
		if visited.has(cell):
			continue
		var region : Array[Vector2i] = []
		var stack : Array[Vector2i] = [cell]
		visited[cell] = true
		while not stack.is_empty():
			var current : Vector2i = stack.pop_back()
			region.append(current)
			for dir : Vector2i in NEIGHBOURS:
				var next : Vector2i = current + dir
				if in_set.has(next) and not visited.has(next):
					visited[next] = true
					stack.append(next)
		regions.append(region)
	return regions
	
	

func _scatter_props(data : MapData, cells : Array[Vector2i], rng : RandomNumberGenerator) -> void:
	if prop_textures.is_empty() or prop_chance <= 0.0:
		return
	var parent : Node2D = props_parent if props_parent != null else self
	if _props_root != null and is_instance_valid(_props_root):
		_props_root.queue_free()
	_props_root = Node2D.new()
	_props_root.name = "SidewalkProps"
	parent.add_child(_props_root)

	var cell_px : float = float(data.cell_size)
	var placed : Array[Vector2i] = []
	var min_dist_sq : int = prop_min_distance * prop_min_distance
	var count : int = 0
	var rejected : int = 0

	for cell : Vector2i in cells:
		# get_sidewalk_cells() also returns the building footprints, since the
		# pavement runs under them: props must stay on visible ground only
		if data.cell_type(cell.x, cell.y) != MapData.CellType.SIDEWALK:
			continue
		if rng.randf() > prop_chance:
			continue

		var texture : Texture2D = prop_textures[rng.randi_range(0, prop_textures.size() - 1)]
		# Quarter turns swap width and height, so the footprint is the largest
		# side on both axes. The jitter is added in: without it a decal centred
		# on the last pavement cell still hangs over the roadway.
		var extent_px : float = maxf(float(texture.get_width()), float(texture.get_height())) * 0.5 + prop_jitter_px
		var margin : int = int(ceil(extent_px / cell_px - 0.5))
		if not _footprint_is_pavement(data, cell, margin):
			rejected += 1
			continue

		# Keep props apart: cheap linear check, the placed list stays small
		var too_close : bool = false
		for other : Vector2i in placed:
			var delta : Vector2i = cell - other
			if delta.x * delta.x + delta.y * delta.y < min_dist_sq:
				too_close = true
				break
		if too_close:
			continue

		var sprite : Sprite2D = Sprite2D.new()
		sprite.texture = texture
		sprite.position = (Vector2(cell) + Vector2(0.5, 0.5)) * cell_px \
				+ Vector2(rng.randf_range(-prop_jitter_px, prop_jitter_px),
						rng.randf_range(-prop_jitter_px, prop_jitter_px))
		if random_quarter_turns:
			sprite.rotation = float(rng.randi_range(0, 3)) * PI * 0.5
		_props_root.add_child(sprite)
		placed.append(cell)
		count += 1

	print("[MapSidewalks] scattered ", count, " props (", rejected, " rejected for overflowing)")
	
	
func _footprint_is_pavement(data : MapData, cell : Vector2i, margin : int) -> bool:
	# Every cell the sprite can cover must be visible pavement: not a road, and
	# not a building footprint either.
	if margin <= 0:
		return true
	for y : int in range(cell.y - margin, cell.y + margin + 1):
		for x : int in range(cell.x - margin, cell.x + margin + 1):
			if x < 0 or y < 0 or x >= data.map_size_cells.x or y >= data.map_size_cells.y:
				return false
			if data.cell_type(x, y) != MapData.CellType.SIDEWALK:
				return false
	return true
