class_name MapRoadLines
extends Node2D
## Longitudinal road markings: centre lines and lane lines.
##
## Edges are chained through every degree-2 node, so a bend keeps a continuous
## marking that follows the curve instead of leaving the corner bare. Chains
## are cut only at real intersections (degree >= 3), where US practice drops
## centre and lane lines through the crossing.
##
## The two templates carry the whole look (colours, offsets, dash pattern,
## wear) in their `lines` array; this pass only supplies the curve.

## RoadMarkingPath2D scene configured for a street (2 lanes, one each way)
@export var street_template : PackedScene = null
## RoadMarkingPath2D scene configured for an artery (4 lanes, two each way)
@export var artery_template : PackedScene = null
## Clearance kept between the crossing road and the start of the lines, in
## cells. Raise it to also clear the crosswalk band.
@export var line_stop_cells : int = 4
## Chains shorter than this once trimmed get no marking at all
@export var min_line_length_cells : int = 4
## Radius of the rounded corner at a bend, in cells
@export var corner_radius_cells : int = 6
@export var use_map_seed : bool = true

const BEZIER_CIRCLE_K : float = 0.5523  # quarter-circle bezier handle ratio

var _data : MapData = null
var _degrees : PackedInt32Array = PackedInt32Array()
var _built : int = 0


func build(data : MapData) -> void:
	for child : Node in get_children():
		child.queue_free()
	_data = data
	_built = 0

	if street_template == null and artery_template == null:
		push_error("[MapRoadLines] no template assigned")
		return

	_degrees = _node_degrees()
	var used : Array[bool] = []
	used.resize(data.edges.size())
	used.fill(false)

	for edge_index : int in data.edges.size():
		if used[edge_index]:
			continue
		var chain : Array[int] = _build_chain(edge_index, used)
		_spawn_chain(chain, data.edge_is_artery[edge_index], edge_index)

	print("[MapRoadLines] built ", _built, " marking chains")


func _node_degrees() -> PackedInt32Array:
	var degrees : PackedInt32Array = PackedInt32Array()
	degrees.resize(_data.nodes.size())
	for edge : Vector2i in _data.edges:
		degrees[edge.x] += 1
		degrees[edge.y] += 1
	return degrees


# =================================================================
# CHAINS
# =================================================================
func _build_chain(edge_index : int, used : Array[bool]) -> Array[int]:
	# Ordered node list, extended through every degree-2 node of the same
	# road type. Bends are kept inside the chain, intersections end it.
	var edge : Vector2i = _data.edges[edge_index]
	used[edge_index] = true
	var artery : bool = _data.edge_is_artery[edge_index]
	var chain : Array[int] = [edge.x, edge.y]
	_extend(chain, used, artery, false)
	_extend(chain, used, artery, true)
	return chain


func _extend(chain : Array[int], used : Array[bool], artery : bool, backwards : bool) -> void:
	while true:
		var end_node : int = chain[0] if backwards else chain[chain.size() - 1]
		if _degrees[end_node] != 2:
			return  # intersection or border stub: the chain ends here
		var next_edge : int = -1
		for i : int in _data.edges.size():
			if used[i] or _data.edge_is_artery[i] != artery:
				continue
			var candidate : Vector2i = _data.edges[i]
			if candidate.x == end_node or candidate.y == end_node:
				next_edge = i
				break
		if next_edge == -1:
			return
		used[next_edge] = true
		var picked : Vector2i = _data.edges[next_edge]
		var other : int = picked.y if picked.x == end_node else picked.x
		if backwards:
			chain.insert(0, other)
		else:
			chain.append(other)


# =================================================================
# GEOMETRY
# =================================================================
func _spawn_chain(chain : Array[int], is_artery : bool, seed_offset : int) -> void:
	var px : float = float(_data.cell_size)
	var stop : float = float(line_stop_cells) * px
	var last : int = chain.size() - 1

	var points : Array[Vector2] = []
	for node_index : int in chain:
		points.append(_data.nodes[node_index] * px)

	# Trim only at real intersections; a border stub runs to the map edge
	var dir_start : Vector2 = (points[1] - points[0]).normalized()
	if _degrees[chain[0]] >= 3:
		points[0] += dir_start * (_cross_half_width(chain[0], dir_start) + stop)
	var dir_end : Vector2 = (points[last] - points[last - 1]).normalized()
	if _degrees[chain[last]] >= 3:
		points[last] -= dir_end * (_cross_half_width(chain[last], dir_end) + stop)

	if points[0].distance_to(points[last]) < float(min_line_length_cells) * px:
		return

	var curve : Curve2D = Curve2D.new()
	curve.add_point(points[0])
	for i : int in range(1, last):
		_add_corner(curve, points[i - 1], points[i], points[i + 1], px)
	curve.add_point(points[last])
	if curve.get_point_count() < 2:
		return

	_spawn_marking(curve, is_artery, seed_offset)


func _add_corner(curve : Curve2D, previous : Vector2, corner : Vector2, following : Vector2, px : float) -> void:
	# A collinear node is not a bend: skipping it keeps the curve straight
	var dir_in : Vector2 = (corner - previous).normalized()
	var dir_out : Vector2 = (following - corner).normalized()
	if dir_in.dot(dir_out) > 0.99:
		return

	# Radius clamped so two close bends cannot overlap
	var radius : float = minf(float(corner_radius_cells) * px,
			minf(previous.distance_to(corner), corner.distance_to(following)) * 0.45)
	var handle : float = radius * BEZIER_CIRCLE_K
	curve.add_point(corner - dir_in * radius, Vector2.ZERO, dir_in * handle)
	curve.add_point(corner + dir_out * radius, -dir_out * handle, Vector2.ZERO)


func _spawn_marking(curve : Curve2D, is_artery : bool, seed_offset : int) -> void:
	var template : PackedScene = artery_template if is_artery else street_template
	if template == null:
		template = street_template if street_template != null else artery_template
	if template == null:
		return

	var path : Path2D = template.instantiate() as Path2D
	if path == null:
		push_error("[MapRoadLines] template root must be a Path2D (RoadMarkingPath2D)")
		return

	path.curve = curve  # set BEFORE add_child so the tool's _ready sees it
	if use_map_seed:
		# Vary the wear pattern per chain without breaking determinism
		var lines : Variant = path.get("lines")
		if lines != null:
			for line : Resource in lines:
				if line != null and "line_seed" in line:
					line.line_seed = _data.seed_used + seed_offset
	add_child(path)
	_built += 1


func _cross_half_width(node_index : int, dir : Vector2) -> float:
	# Half width of the widest road CROSSING this approach: what the marking
	# must stop before. Returns 0 at a border stub, so the line runs to the edge.
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
