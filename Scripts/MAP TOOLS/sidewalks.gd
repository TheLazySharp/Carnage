class_name MapSidewalks
extends Node2D
## Sidewalk pass. Runs AFTER the building placement, since the sidewalk is
## whatever is left once roads and buildings are marked.
##
## The whole set is painted in ONE set_cells_terrain_connect() call: that is
## what lets Godot resolve the corner joints globally. Painting block by block
## would produce a seam wherever two painted groups touch.

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

	var terrain : int = terrains[rng.randi_range(0, terrains.size() - 1)]
	layer.set_cells_terrain_connect(cells, terrain_set, terrain, false)
	print("[MapSidewalks] painted ", cells.size(), " cells with terrain ", terrain)

	_scatter_props(data, cells, rng)


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

	for cell : Vector2i in cells:
		# get_sidewalk_cells() also returns the building footprints, since the
		# pavement runs under them: props must stay on visible ground only
		if data.cell_type(cell.x, cell.y) != MapData.CellType.SIDEWALK:
			continue
		if rng.randf() > prop_chance:
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
		sprite.texture = prop_textures[rng.randi_range(0, prop_textures.size() - 1)]
		sprite.position = (Vector2(cell) + Vector2(0.5, 0.5)) * cell_px \
				+ Vector2(rng.randf_range(-prop_jitter_px, prop_jitter_px),
						rng.randf_range(-prop_jitter_px, prop_jitter_px))
		if random_quarter_turns:
			sprite.rotation = float(rng.randi_range(0, 3)) * PI * 0.5
		_props_root.add_child(sprite)
		placed.append(cell)
		count += 1

	print("[MapSidewalks] scattered ", count, " props")
