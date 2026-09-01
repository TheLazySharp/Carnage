class_name MapRoadMarks
extends Node2D
## Road marking pass, in two stages:
##   1. every crosswalk is placed and its rect recorded
##   2. arrows are placed, and any arrow overlapping a recorded crosswalk is
##      dropped — including the crosswalk of the perpendicular road
##
## Markings are flat paint with no baked shadow, so a single asset per type is
## rotated to the travel direction (90 degree steps, exact in pixel art).
##
## ASSET CONVENTIONS:
## - crosswalk scenes are centered on their origin, their LONG axis spanning
##   the road width; crosswalk_base_rotation_deg corrects the authored side
## - arrow textures point UP; arrow_base_rotation_deg corrects the convention

@export_group("Crosswalks")
@export var build_crosswalks : bool = true
## Authored at the street width (street_lanes * lane_width_px)
@export var crosswalk_street : PackedScene = null
## Authored at the artery width (artery_lanes * lane_width_px)
@export var crosswalk_artery : PackedScene = null
## Gap between the intersection box and the crosswalk, in cells
@export var crosswalk_gap_cells : int = 1
## Correction if the asset is drawn for the other road orientation
@export var crosswalk_base_rotation_deg : float = 90.0
## Depth of the crosswalk asset along the road, in cells (a 192x96 asset = 3)
@export var crosswalk_depth_cells : int = 3
## Edges shorter than this get no crosswalk at all
@export var min_edge_length_cells : int = 10
## Share of the eligible approaches that actually get a crosswalk
@export_range(0.0, 1.0, 0.05) var crosswalk_chance : float = 1.0
## Minimum clear distance between the two crosswalks of one segment, in cells.
## Below that, only one is kept: one crossing per face.
@export var min_crosswalk_spacing_cells : int = 6

@export_group("Arrows")
@export var build_arrows : bool = true
@export var arrows_straight : Array[Texture2D] = []
@export var arrows_left : Array[Texture2D] = []
@export var arrows_right : Array[Texture2D] = []
@export var arrows_straight_left : Array[Texture2D] = []
@export var arrows_straight_right : Array[Texture2D] = []
## US practice: a single-lane approach carries no lane-use arrow.
## Enable to mark the small streets too.
@export var arrows_on_streets : bool = false
## Arrows per lane, counted back from the stop line
@export var arrow_repeat : int = 2
## Distance between two repeated arrows, in cells
@export var arrow_repeat_spacing_cells : int = 8
## Clear space between the crosswalk band and the arrow tip, in cells
@export var arrow_stop_line_cells : int = 1
## Share of the approach lanes that actually get an arrow
@export_range(0.0, 1.0, 0.05) var arrow_chance : float = 0.85
## Correction if the atlas arrows do not point up
@export var arrow_base_rotation_deg : float = 0.0
## Extra clearance kept around every crosswalk when testing an arrow, in cells
@export var arrow_clearance_cells : int = 1
## Only mark an approach that actually received a crosswalk
@export var arrows_only_with_crosswalk : bool = true

var _data : MapData = null
var _rng : RandomNumberGenerator = RandomNumberGenerator.new()
## World rects of the placed crosswalks, tested against every arrow
var _crosswalk_rects : Array[Rect2] = []
var _crosswalks : int = 0
var _arrows : int = 0
var _rejected : int = 0
## Approaches that got a crosswalk, keyed by (edge index, node index)
var _crosswalk_approaches : Dictionary = {}

func build(data : MapData) -> void:
	for child : Node in get_children():
		child.queue_free()
	_data = data
	_rng.seed = data.seed_used ^ 0x4A11  # own stream
	_crosswalk_rects.clear()
	_crosswalks = 0
	_arrows = 0
	_rejected = 0

	var degrees : PackedInt32Array = _node_degrees()

	# Stage 1: every crosswalk, recording its footprint
	for edge_index : int in data.edges.size():
		_mark_crosswalks(edge_index, degrees)
	# Stage 2: arrows, now able to avoid every crosswalk on the map
	for edge_index : int in data.edges.size():
		_mark_arrows_on_edge(edge_index, degrees)

	print("[MapRoadMarks] ", _crosswalks, " crosswalks, ", _arrows, " arrows (",
			_rejected, " dropped for overlapping a crossing)")


func _node_degrees() -> PackedInt32Array:
	var degrees : PackedInt32Array = PackedInt32Array()
	degrees.resize(_data.nodes.size())
	for edge : Vector2i in _data.edges:
		degrees[edge.x] += 1
		degrees[edge.y] += 1
	return degrees


# =================================================================
# STAGE 1 : CROSSWALKS
# =================================================================
func _mark_crosswalks(edge_index : int, degrees : PackedInt32Array) -> void:
	var px : float = float(_data.cell_size)
	var edge : Vector2i = _data.edges[edge_index]
	var a : Vector2 = _data.nodes[edge.x] * px
	var b : Vector2 = _data.nodes[edge.y] * px
	var length : float = a.distance_to(b)
	if length < float(min_edge_length_cells) * px:
		return  # too short to be a real street section

	var dir : Vector2 = (b - a).normalized()  # a -> b
	var gap : float = float(crosswalk_gap_cells) * px
	var depth : float = float(crosswalk_depth_cells) * px
	# Each crosswalk clears the road CROSSING its approach, not the widest one
	var dist_a : float = _cross_half_width(edge.x, dir) + gap + depth * 0.5
	var dist_b : float = _cross_half_width(edge.y, dir) + gap + depth * 0.5

	var at_a : bool = degrees[edge.x] >= 3
	var at_b : bool = degrees[edge.y] >= 3
	# One crossing per face: on a short segment the two bands would sit side by
	# side, so keep only the one serving the widest intersection
	if at_a and at_b:
		var free_span : float = length - (dist_a + dist_b + depth)
		if free_span < float(min_crosswalk_spacing_cells) * px:
			if _node_half_width(edge.x) >= _node_half_width(edge.y):
				at_b = false
			else:
				at_a = false
	if at_a and dist_a + depth * 0.5 > length:
		at_a = false
	if at_b and dist_b + depth * 0.5 > length:
		at_b = false

	var is_artery : bool = _data.edge_is_artery[edge_index]
	if at_b and _spawn_crosswalk(b - dir * dist_b, dir, is_artery):
		_crosswalk_approaches[Vector2i(edge_index, edge.y)] = true
	if at_a and _spawn_crosswalk(a + dir * dist_a, dir, is_artery):
		_crosswalk_approaches[Vector2i(edge_index, edge.x)] = true


func _spawn_crosswalk(p_position : Vector2, dir : Vector2, is_artery : bool) -> bool:
	if not build_crosswalks:
		return false
	if _rng.randf() > crosswalk_chance:
		return false
	var scene : PackedScene = crosswalk_artery if is_artery else crosswalk_street
	if scene == null:
		return false
	var instance : Node2D = scene.instantiate() as Node2D
	if instance == null:
		push_error("[MapRoadMarks] crosswalk scene root must be a Node2D")
		return false
	instance.position = p_position
	instance.rotation = dir.angle() + deg_to_rad(crosswalk_base_rotation_deg)
	add_child(instance)
	_crosswalks += 1

	# Record the footprint: roads are axis aligned, so the rect is exact
	var road_width : float = _data.artery_width_px() if is_artery else _data.street_width_px()
	var depth : float = float(crosswalk_depth_cells) * float(_data.cell_size)
	var size : Vector2 = Vector2(depth, road_width) if absf(dir.x) > 0.5 else Vector2(road_width, depth)
	_crosswalk_rects.append(Rect2(position - size * 0.5, size))
	return true


# =================================================================
# STAGE 2 : ARROWS
# =================================================================
func _mark_arrows_on_edge(edge_index : int, degrees : PackedInt32Array) -> void:
	var px : float = float(_data.cell_size)
	var edge : Vector2i = _data.edges[edge_index]
	var a : Vector2 = _data.nodes[edge.x] * px
	var b : Vector2 = _data.nodes[edge.y] * px
	var length : float = a.distance_to(b)
	if length < float(min_edge_length_cells) * px:
		return
	var dir : Vector2 = (b - a).normalized()

	if degrees[edge.y] >= 3 and _approach_marked(edge_index, edge.y):
		_mark_arrows(edge_index, edge.x, edge.y, dir, length)
	if degrees[edge.x] >= 3 and _approach_marked(edge_index, edge.x):
		_mark_arrows(edge_index, edge.y, edge.x, -dir, length)


func _mark_arrows(edge_index : int, from_node : int, to_node : int, dir : Vector2, length : float) -> void:
	if not build_arrows:
		return
	var lanes : int = _data.artery_lanes if _data.edge_is_artery[edge_index] else _data.street_lanes
	if lanes <= 2 and not arrows_on_streets:
		return  # MUTCD: single-lane approaches carry no lane-use arrow

	var px : float = float(_data.cell_size)
	# Start after the crosswalk band of this very approach
	var band_end : float = _cross_half_width(to_node, dir) \
		+ float(crosswalk_gap_cells) * px + float(crosswalk_depth_cells) * px
	var stop_line : float = band_end + float(arrow_stop_line_cells) * px
	var stop_pos : Vector2 = _data.nodes[to_node] * px - dir * stop_line
	var upstream_limit : float = length - _cross_half_width(from_node, dir)

	for i : int in maxi(arrow_repeat, 1):
		var back : float = float(i) * float(arrow_repeat_spacing_cells) * px
		if stop_line + back > upstream_limit:
			break  # would land inside the upstream intersection
		_spawn_arrows(stop_pos - dir * back, dir, edge_index, to_node)


func _spawn_arrows(p_position : Vector2, dir : Vector2, edge_index : int, to_node : int) -> void:
	var right : Vector2 = Vector2(-dir.y, dir.x)
	var turns : Dictionary = _available_turns(dir, right, edge_index, to_node)
	var offsets : PackedFloat32Array = _outbound_lane_offsets(edge_index)

	for i : int in offsets.size():
		if _rng.randf() > arrow_chance:
			continue
		# i = 0 is the rightmost lane
		var pool : Array[Texture2D] = _arrow_pool(turns, i == 0, i == offsets.size() - 1)
		if pool.is_empty():
			continue
		var texture : Texture2D = pool[_rng.randi_range(0, pool.size() - 1)]

		# `position` is the stop line: the arrow tip lands there, body behind it
		var half_length : float = float(texture.get_height()) * 0.5
		var center : Vector2 = p_position + right * offsets[i] - dir * half_length
		if _overlaps_crosswalk(center, texture, dir):
			_rejected += 1
			continue

		var sprite : Sprite2D = Sprite2D.new()
		sprite.texture = texture
		sprite.position = center
		# Textures point up: the direction angle plus 90 degrees makes them
		# follow the travel direction
		sprite.rotation = dir.angle() + PI * 0.5 + deg_to_rad(arrow_base_rotation_deg)
		add_child(sprite)
		_arrows += 1


func _overlaps_crosswalk(center : Vector2, texture : Texture2D, dir : Vector2) -> bool:
	# The arrow texture points up, so a horizontal road swaps its dimensions
	var size : Vector2 = Vector2(float(texture.get_height()), float(texture.get_width())) \
		if absf(dir.x) > 0.5 else Vector2(float(texture.get_width()), float(texture.get_height()))
	var clearance : Vector2 = Vector2.ONE * float(arrow_clearance_cells) * float(_data.cell_size)
	var rect : Rect2 = Rect2(center - size * 0.5 - clearance, size + clearance * 2.0)
	for other : Rect2 in _crosswalk_rects:
		if rect.intersects(other):
			return true
	return false


func _available_turns(dir : Vector2, right : Vector2, edge_index : int, to_node : int) -> Dictionary:
	# Which movements the graph allows once the intersection is reached
	var result : Dictionary = {"straight": false, "left": false, "right": false}
	for i : int in _data.edges.size():
		if i == edge_index:
			continue
		var edge : Vector2i = _data.edges[i]
		var other : int = -1
		if edge.x == to_node:
			other = edge.y
		elif edge.y == to_node:
			other = edge.x
		else:
			continue
		var branch : Vector2 = (_data.nodes[other] - _data.nodes[to_node]).normalized()
		if branch.dot(dir) > 0.9:
			result["straight"] = true
		elif branch.dot(right) > 0.9:
			result["right"] = true
		elif branch.dot(right) < -0.9:
			result["left"] = true
	return result


func _arrow_pool(turns : Dictionary, is_rightmost : bool, is_leftmost : bool) -> Array[Texture2D]:
	# Rightmost lane takes the right turns, leftmost takes the left ones,
	# middle lanes stay straight
	var straight : bool = turns["straight"]
	var can_right : bool = turns["right"] and is_rightmost
	var can_left : bool = turns["left"] and is_leftmost

	if straight and can_right:
		return arrows_straight_right if not arrows_straight_right.is_empty() else arrows_straight
	if straight and can_left:
		return arrows_straight_left if not arrows_straight_left.is_empty() else arrows_straight
	if can_right and not straight:
		return arrows_right
	if can_left and not straight:
		return arrows_left
	if straight:
		return arrows_straight
	return []


func _outbound_lane_offsets(edge_index : int) -> PackedFloat32Array:
	# Lane centers on the right half of the road, rightmost first.
	# 2 lanes -> [+0.5] ; 4 lanes -> [+1.5, +0.5] (times the lane width)
	var lanes : int = _data.artery_lanes if _data.edge_is_artery[edge_index] else _data.street_lanes
	var lane_w : float = float(_data.lane_width_px)
	var result : PackedFloat32Array = PackedFloat32Array()
	for i : int in range(lanes - 1, -1, -1):
		var offset : float = (float(i) - float(lanes - 1) * 0.5) * lane_w
		if offset > 0.0:
			result.append(offset)
	return result


# =================================================================
# GEOMETRY HELPERS
# =================================================================
func _node_half_width(node_index : int) -> float:
	# Half of the widest road touching the node: used to rank intersections
	var widest : float = 0.0
	for i : int in _data.edges.size():
		var edge : Vector2i = _data.edges[i]
		if edge.x == node_index or edge.y == node_index:
			widest = maxf(widest, _data.edge_width_px(i))
	return widest * 0.5


func _cross_half_width(node_index : int, dir : Vector2) -> float:
	# Half width of the widest road CROSSING the approach at this node. That is
	# what a marking must clear, not the widest road of the intersection.
	var widest : float = 0.0
	for i : int in _data.edges.size():
		var edge : Vector2i = _data.edges[i]
		var other : int = -1
		if edge.x == node_index:
			other = edge.y
		elif edge.y == node_index:
			other = edge.x
		else:
			continue
		var branch : Vector2 = (_data.nodes[other] - _data.nodes[node_index]).normalized()
		if absf(branch.dot(dir)) < 0.5:  # perpendicular branch
			widest = maxf(widest, _data.edge_width_px(i))
	return widest * 0.5


func _approach_marked(edge_index : int, node_index : int) -> bool:
	if not arrows_only_with_crosswalk:
		return true
	return _crosswalk_approaches.has(Vector2i(edge_index, node_index))
