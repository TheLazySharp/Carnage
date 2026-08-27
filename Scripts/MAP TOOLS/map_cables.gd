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
@export var max_span_cells : int = 24
## Minimum distance between two cables, in cells (compared on their midpoints)
@export var min_distance_cells : int = 12
## How deep the anchors bite into the roofs, in cells
@export var anchor_inset_cells : int = 1

@export_group("Chaos")
## Sideways wander of each anchor along its facade, in cells. This is what
## breaks the perfectly horizontal / vertical look.
@export var anchor_jitter_cells : float = 2.5
## Chance a corner also shoots its diagonal ray, spanning an intersection
@export_range(0.0, 1.0, 0.05) var diagonal_chance : float = 0.4
## Chance a cable also fans out to a second, neighbouring building
@export_range(0.0, 1.0, 0.05) var fan_chance : float = 0.3
## Sideways offsets probed to find that second building, in cells
@export var fan_probe_cells : int = 5


var _placed_midpoints : Array[Vector2] = []
var _built : int = 0
var _rng : RandomNumberGenerator = RandomNumberGenerator.new()

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
			if dir.x != 0 and dir.y != 0 and rng.randf() > diagonal_chance:
				continue

			var hit : Vector2i = _cast(data, corner, dir)
			if hit == Vector2i(-1, -1):
				continue
			var target : int = _rect_at(hit, building_rects)
			if target == index or target == -1:
				continue
			if rng.randf() > cable_chance:
				continue

			var start : Vector2 = _anchor(corner, dir, -1.0, rect, cell, rng)
			var stop : Vector2 = _anchor(hit, dir, 1.0, building_rects[target], cell, rng)
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

			# Fan: a second cable leaving the SAME anchor towards a neighbouring
			# building, so two lines diverge from one pole-like point. It is
			# exempt from the min distance rule on purpose, it IS a close pair.
			if rng.randf() >= fan_chance:
				continue
			var fan_hit : Vector2i = _fan_hit(data, corner, dir, index, target, building_rects)
			if fan_hit == Vector2i(-1, -1):
				continue
			var fan_index : int = _rect_at(fan_hit, building_rects)
			_spawn_cable(start, _anchor(fan_hit, dir, 1.0, building_rects[fan_index], cell, rng))

	print("[MapCables] built ", _built, " cables")


func _corner_rays(rect : Rect2i) -> Array[Array]:
	# The 4 corners, each with its 2 outward axis directions plus its diagonal
	var left : int = rect.position.x
	var top : int = rect.position.y
	var right : int = rect.end.x - 1
	var bottom : int = rect.end.y - 1
	return [
		[Vector2i(left, top), Vector2i(-1, 0)],
		[Vector2i(left, top), Vector2i(0, -1)],
		[Vector2i(left, top), Vector2i(-1, -1)],
		[Vector2i(right, top), Vector2i(1, 0)],
		[Vector2i(right, top), Vector2i(0, -1)],
		[Vector2i(right, top), Vector2i(1, -1)],
		[Vector2i(right, bottom), Vector2i(1, 0)],
		[Vector2i(right, bottom), Vector2i(0, 1)],
		[Vector2i(right, bottom), Vector2i(1, 1)],
		[Vector2i(left, bottom), Vector2i(-1, 0)],
		[Vector2i(left, bottom), Vector2i(0, 1)],
		[Vector2i(left, bottom), Vector2i(-1, 1)],
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
	if shadow.has_method("randomize_sag_now"):
		shadow.call("randomize_sag_now", int(_rng.randi()))
	# Relative NodePath, resolved by CableShadow once both are in the tree
	shadow.set("cable_path", shadow.get_path_to(cable))


func _anchor(cell_pos : Vector2i, dir : Vector2i, inset_sign : float, rect : Rect2i,
		cell_size : float, rng : RandomNumberGenerator) -> Vector2:
	# Cell centre, pushed into the roof along the ray, then slid sideways along
	# the facade. Clamped back inside the roof so the cable stays attached.
	var dir_f : Vector2 = Vector2(dir).normalized()
	var perp : Vector2 = Vector2(-dir_f.y, dir_f.x)
	var jitter : float = anchor_jitter_cells * cell_size
	var point : Vector2 = _cell_center(cell_pos, cell_size) \
			+ dir_f * inset_sign * float(anchor_inset_cells) * cell_size \
			+ perp * rng.randf_range(-jitter, jitter)
	return _clamp_to_rect(point, rect, cell_size)


func _clamp_to_rect(point : Vector2, rect : Rect2i, cell_size : float) -> Vector2:
	var margin : float = cell_size * 0.5
	var low : Vector2 = Vector2(rect.position) * cell_size + Vector2(margin, margin)
	var high : Vector2 = Vector2(rect.end) * cell_size - Vector2(margin, margin)
	return Vector2(clampf(point.x, low.x, maxf(low.x, high.x)),
			clampf(point.y, low.y, maxf(low.y, high.y)))


func _fan_hit(data : MapData, corner : Vector2i, dir : Vector2i, source : int,
		first_target : int, building_rects : Array[Rect2i]) -> Vector2i:
	# Probes rays parallel to the first one, offset sideways, looking for a
	# DIFFERENT building: typically the one next door across the same street.
	var perp : Vector2i = Vector2i(-dir.y, dir.x)
	for offset : int in range(1, fan_probe_cells + 1):
		for side : int in [offset, -offset]:
			var hit : Vector2i = _cast(data, corner + perp * side, dir)
			if hit == Vector2i(-1, -1):
				continue
			var found : int = _rect_at(hit, building_rects)
			if found == -1 or found == source or found == first_target:
				continue
			return hit
	return Vector2i(-1, -1)
