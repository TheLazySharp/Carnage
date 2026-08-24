class_name MapCables
extends Node2D
## Overhead cable pass. Runs AFTER the building placement and BEFORE the
## shadow bake, since it feeds CableShadow nodes into the shared shadow layer.
##
## A cable links a CORNER of a building to the first building found straight
## across a road. Candidates are found by casting a ray from every building
## corner: the ray must cross at least one road cell before hitting another
## building, which guarantees the cable spans a street and never a sidewalk.
##
## REQUIREMENT: this node and the MapShadowsGround node must both sit at
## position (0, 0) without scale or rotation. Cable points are stored in
## absolute map pixels, and CableShadow converts through global space.

## PixelLine2D scene, pre-configured (pixel_size, thickness, color).
## Keep its draw_shadow OFF: the ground shadow is handled by shadow_scene.
@export var cable_scene : PackedScene = null
## CableShadow scene, pre-configured (sag, direction, opaque color)
@export var shadow_scene : PackedScene = null
## Shared shadow layer the cable shadows are parented to
@export var shadows_ground : MapShadowsGround = null

@export_group("Placement")
## Share of the valid candidates actually kept
@export_range(0.0, 1.0, 0.05) var cable_chance : float = 0.75
## Longest span a cable may cover, in cells
@export var max_span_cells : int = 20
## Minimum distance between two cables, in cells (compared on their midpoints)
@export var min_distance_cells : int = 6
## How deep the anchors bite into the roofs, in cells
@export var anchor_inset_cells : int = 1

var _placed_midpoints : Array[Vector2] = []
var _built : int = 0


func build(data : MapData, building_rects : Array[Rect2i]) -> void:
	for child : Node in get_children():
		child.queue_free()
	_placed_midpoints.clear()
	_built = 0

	if cable_scene == null:
		push_error("[MapCables] no cable_scene assigned")
		return
	if building_rects.is_empty():
		print("[MapCables] no building on the map: no cable")
		return

	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = data.seed_used ^ 0xCAB1E  # own stream

	var cell : float = float(data.cell_size)
	var min_dist_sq : float = pow(float(min_distance_cells) * cell, 2.0)

	for index : int in building_rects.size():
		var rect : Rect2i = building_rects[index]
		for corner_data : Array in _corner_rays(rect):
			var corner : Vector2i = corner_data[0]
			var dir : Vector2i = corner_data[1]

			var hit : Vector2i = _cast(data, corner, dir)
			if hit == Vector2i(-1, -1):
				continue
			var target : int = _rect_at(hit, building_rects)
			if target == index or target == -1:
				continue
			if rng.randf() > cable_chance:
				continue

			# Anchors: corner pushed into its own roof, far end pushed into the
			# facing roof, so the cable visually attaches instead of floating
			var start : Vector2 = _cell_center(corner, cell) - Vector2(dir) * float(anchor_inset_cells) * cell
			var stop : Vector2 = _cell_center(hit, cell) + Vector2(dir) * float(anchor_inset_cells) * cell
			var midpoint : Vector2 = (start + stop) * 0.5

			var too_close : bool = false
			for other : Vector2 in _placed_midpoints:
				if midpoint.distance_squared_to(other) < min_dist_sq:
					too_close = true
					break
			if too_close:
				continue

			_spawn_cable(start, stop)
			_placed_midpoints.append(midpoint)

	print("[MapCables] built ", _built, " cables")


func _corner_rays(rect : Rect2i) -> Array[Array]:
	# The 4 corners, each with the 2 outward directions it can shoot at
	var left : int = rect.position.x
	var top : int = rect.position.y
	var right : int = rect.end.x - 1
	var bottom : int = rect.end.y - 1
	return [
		[Vector2i(left, top), Vector2i(-1, 0)],
		[Vector2i(left, top), Vector2i(0, -1)],
		[Vector2i(right, top), Vector2i(1, 0)],
		[Vector2i(right, top), Vector2i(0, -1)],
		[Vector2i(right, bottom), Vector2i(1, 0)],
		[Vector2i(right, bottom), Vector2i(0, 1)],
		[Vector2i(left, bottom), Vector2i(-1, 0)],
		[Vector2i(left, bottom), Vector2i(0, 1)],
	]


func _cast(data : MapData, from_cell : Vector2i, dir : Vector2i) -> Vector2i:
	# Walks the grid until it hits a building. Returns (-1, -1) unless at least
	# one road cell was crossed on the way: no cable over a mere sidewalk.
	var current : Vector2i = from_cell
	var crossed_road : bool = false
	for _step : int in max_span_cells:
		current += dir
		if current.x < 0 or current.y < 0 \
			or current.x >= data.map_size_cells.x or current.y >= data.map_size_cells.y:
			return Vector2i(-1, -1)
		var type : int = data.cell_type(current.x, current.y)
		if type == MapData.CellType.STREET or type == MapData.CellType.ARTERY:
			crossed_road = true
		elif type == MapData.CellType.BUILDING:
			return current if crossed_road else Vector2i(-1, -1)
	return Vector2i(-1, -1)


func _rect_at(cell : Vector2i, building_rects : Array[Rect2i]) -> int:
	for i : int in building_rects.size():
		if building_rects[i].has_point(cell):
			return i
	return -1


func _cell_center(cell : Vector2i, cell_size : float) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func _spawn_cable(start : Vector2, stop : Vector2) -> void:
	var cable : Line2D = cable_scene.instantiate() as Line2D
	if cable == null:
		push_error("[MapCables] cable_scene root must be a Line2D (PixelLine2D)")
		return
	cable.position = Vector2.ZERO
	cable.points = PackedVector2Array([start, stop])
	add_child(cable)
	_built += 1

	if shadow_scene == null or shadows_ground == null:
		return
	var shadow : Node2D = shadow_scene.instantiate() as Node2D
	if shadow == null:
		return
	shadow.position = Vector2.ZERO
	shadows_ground.add_child(shadow)
	# Relative NodePath, resolved by CableShadow once both are in the tree
	shadow.set("cable_path", shadow.get_path_to(cable))
