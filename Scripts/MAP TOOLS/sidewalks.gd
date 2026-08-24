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
## Flat decals scattered on the sidewalk (manholes, drains, grates...).
## Tiles of this layer are picked at random among prop_tiles.
@export var props_layer : TileMapLayer = null
@export var prop_source_id : int = 0
@export var prop_tiles : Array[Vector2i] = []
@export_range(0.0, 0.2, 0.001) var prop_chance : float = 0.01
## Minimum distance between two props, in cells
@export var prop_min_distance : int = 4


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
	if props_layer == null or prop_tiles.is_empty() or prop_chance <= 0.0:
		return
	props_layer.clear()

	var placed : Array[Vector2i] = []
	var min_dist_sq : int = prop_min_distance * prop_min_distance
	var count : int = 0

	for cell : Vector2i in cells:
		if rng.randf() > prop_chance:
			continue
		# Keep props apart: cheap linear check, the placed list stays small
		var too_close : bool = false
		for other : Vector2i in placed:
			var d : Vector2i = cell - other
			if d.x * d.x + d.y * d.y < min_dist_sq:
				too_close = true
				break
		if too_close:
			continue
		props_layer.set_cell(cell, prop_source_id, prop_tiles[rng.randi_range(0, prop_tiles.size() - 1)])
		placed.append(cell)
		count += 1

	print("[MapSidewalks] scattered ", count, " props")
