extends Node2D
class_name MapRoadPaths
## Bridge between the MapData graph and the Path2D drawing tools.
## One Path2D per TRAFFIC LANE, not per road:
##   - straight lane paths, offset laterally from the edge centerline and
##     shortened before each intersection
##   - turn arcs at intersections: quarter-circle beziers joining the lanes
##     of two perpendicular roads, so the wear follows a car trajectory
##     instead of a perpendicular grid
## get_lane_polylines() exposes the same lanes for any other follower (Line2D...).

## Hard cap on the number of turn arcs at one intersection. Bends are exempt:
## there the arc IS the road. This is the main density knob.
@export var max_turns_per_node : int = 6

@export_group("Turn templates")
## Optional. Leave empty to reuse the straight templates. A dedicated brush with
## fade_start_length / fade_end_length set lets the arcs thin out at the
## intersection centre instead of piling up.
@export var street_turn_template : PackedScene = null
@export var artery_turn_template : PackedScene = null

@export var street_template : PackedScene = null   # Path2D-based scene (e.g. RoadBrushPath2D)
@export var artery_template : PackedScene = null   # optional, falls back on street_template
@export var use_map_seed : bool = true             # rng_seed = map seed + index (deterministic)

@export_group("Baking")
## Roads never move: render every stamp ONCE into a SubViewport and keep only
## the resulting texture. Kills the per-frame overdraw of thousands of sprites.
@export var bake_to_texture : bool = true
## Uncheck to keep the source sprites alive (useful while tuning the brush)
@export var free_sources_after_bake : bool = true

@export_group("Lanes")
@export var build_straights : bool = true
@export var build_turns : bool = true
## Corner radius of the turn arcs, in lane widths. Bigger = wider, faster curves.
@export_range(0.5, 4.0, 0.05) var corner_radius_lanes : float = 1.4
## Ratio of possible turns actually drawn at each intersection (organic wear).
@export_range(0.0, 1.0, 0.05) var turn_chance : float = 0.7
## Random lateral offset applied to each lane path, in pixels.
@export var lane_jitter_px : float = 6.0
@export var connection_overlap_px : float = 8.0
## Lateral wander applied along a straight lane, in pixels. Turns a ruler-straight
## band into a slow wave, which is what kills the plaid look at crossings.
@export var lane_wander_px : float = 12.0
## Distance between two wander control points, in pixels
@export var lane_wander_step_px : float = 320.0
## Share of lanes actually worn. Below 1, some lanes stay clean and the grid
## stops reading as a printed pattern.
@export_range(0.0, 1.0, 0.05) var lane_chance : float = 0.85

const BEZIER_CIRCLE_K : float = 0.5523  # quarter-circle bezier handle ratio

var _rng : RandomNumberGenerator = RandomNumberGenerator.new()
var _built : int = 0


func build(data : MapData) -> void:
	for child : Node in get_children():
		child.queue_free()

	if street_template == null:
		push_error("[MapRoadPaths] street_template is empty: assign your RoadBrushPath2D saved as .tscn")
		return

	_rng.seed = data.seed_used
	_built = 0

	if build_straights:
		for lane : Dictionary in get_lane_polylines(data):
			_spawn_path(lane["points"], lane["artery"])
		if build_turns:
			for arc : Dictionary in get_turn_arcs(data):
				_spawn_path(arc["points"], arc["artery"], arc["handles"], true)

	print("[MapRoadPaths] built ", _built, " lane paths")

	if bake_to_texture:
		_bake(Vector2i(data.map_size_cells) * data.cell_size)


# =================================================================
# BAKING
# =================================================================
func _bake(size_px : Vector2i) -> void:
	# Move every generated path into an offscreen viewport, render one frame,
	# then display the result as a single sprite.
	var holder : Node2D = Node2D.new()
	holder.name = "BakeSource"
	var sources : Array[Node] = get_children()
	add_child(holder)
	for child : Node in sources:
		remove_child(child)
		holder.add_child(child)

	var viewport : SubViewport = SubViewport.new()
	viewport.size = size_px
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	remove_child(holder)
	viewport.add_child(holder)
	add_child(viewport)

	# Let the viewport render its single frame
	print("[MapRoadPaths] baking %d paths / %d nodes" % [sources.size(), _count_descendants(holder)])
	await RenderingServer.frame_post_draw

	var sprite : Sprite2D = Sprite2D.new()
	sprite.name = "BakedRoads"
	sprite.texture = viewport.get_texture()
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

	if free_sources_after_bake:
		holder.queue_free()  # the render target keeps the baked image
	print("[MapRoadPaths] baked roads into a %s texture" % str(size_px))


# =================================================================
# STRAIGHT LANES
# =================================================================
func get_lane_polylines(data : MapData) -> Array[Dictionary]:
	# One entry per lane of each straight run:
	# { "points": PackedVector2Array (px), "artery": bool, "offset": float }
	var result : Array[Dictionary] = []
	var lane_w : float = float(data.lane_width_px)
	var radius : float = lane_w * corner_radius_lanes

	for run : Dictionary in _straight_runs(data):
		var a : Vector2 = run["from"]
		var b : Vector2 = run["to"]
		var artery : bool = run["artery"]
		var dir : Vector2 = (b - a).normalized()
		var perp : Vector2 = Vector2(-dir.y, dir.x)

		# Shorten with the CROSSING road's half width, exactly like the turn
		# arcs do. Using the run's own width made streets stop short of the
		# arcs at every street/artery junction.
		var margin_start : float = _cross_half_width(data, run["from_node"], dir) + radius - connection_overlap_px
		var margin_end : float = _cross_half_width(data, run["to_node"], dir) + radius - connection_overlap_px
		var start : Vector2 = a + dir * margin_start
		var stop : Vector2 = b - dir * margin_end
		if start.distance_squared_to(stop) < lane_w * lane_w:
			continue  # run too short once shortened

		for offset : float in _lane_offsets(data, artery):
			if _rng.randf() > lane_chance:
				continue
			var jitter : float = _rng.randf_range(-lane_jitter_px, lane_jitter_px)
			var shift : Vector2 = perp * (offset + jitter)

			# Wandering polyline: the ends stay exact so the lane still meets the
			# turn arcs, only the middle drifts.
			var run_length : float = start.distance_to(stop)
			var steps : int = maxi(int(run_length / lane_wander_step_px), 1)
			var points : PackedVector2Array = PackedVector2Array()
			for s : int in steps + 1:
				var t : float = float(s) / float(steps)
				var wander : float = 0.0
				if s > 0 and s < steps:
					wander = _rng.randf_range(-lane_wander_px, lane_wander_px)
				points.append(start.lerp(stop, t) + shift + perp * wander)

			result.append({
				"points": points,
				"artery": artery,
				"offset": offset,
			})
	return result


func _lane_offsets(data : MapData, artery : bool) -> PackedFloat32Array:
	# Lane centers, symmetrical around the road centerline.
	# 2 lanes -> [-0.5, +0.5] * lane_width ; 4 lanes -> [-1.5, -0.5, +0.5, +1.5]
	var lanes : int = data.artery_lanes if artery else data.street_lanes
	var lane_w : float = float(data.lane_width_px)
	var offsets : PackedFloat32Array = PackedFloat32Array()
	for i : int in lanes:
		offsets.append((float(i) - float(lanes - 1) * 0.5) * lane_w)
	return offsets


# =================================================================
# TURN ARCS
# =================================================================
func get_turn_arcs(data : MapData) -> Array[Dictionary]:
	# One bezier per LANE PAIR, capped per node. A bend curves all its lanes;
	# an intersection keeps at most max_turns_per_node trajectories.
	var px : float = float(data.cell_size)
	var lane_w : float = float(data.lane_width_px)
	var radius : float = lane_w * corner_radius_lanes

	var incident : Array = []
	incident.resize(data.nodes.size())
	for n : int in data.nodes.size():
		incident[n] = []
	for e : int in data.edges.size():
		incident[data.edges[e].x].append(e)
		incident[data.edges[e].y].append(e)

	var result : Array[Dictionary] = []
	for n : int in data.nodes.size():
		var edge_list : Array = incident[n]
		var is_bend : bool = edge_list.size() == 2
		var center : Vector2 = data.nodes[n] * px
		var node_arcs : Array[Dictionary] = []

		for i : int in edge_list.size():
			for j : int in range(i + 1, edge_list.size()):
				var e1 : int = edge_list[i]
				var e2 : int = edge_list[j]
				var d1 : Vector2 = _edge_dir_from(data, e1, n)
				var d2 : Vector2 = _edge_dir_from(data, e2, n)
				if absf(d1.dot(d2)) > 0.01:
					continue  # collinear: no corner here
				var artery : bool = data.edge_is_artery[e1] or data.edge_is_artery[e2]
				for pair : Array in _lane_pairs(data, center, d1, d2, e1, e2, radius, is_bend):
					node_arcs.append(_make_arc(pair[0], pair[1], d1, d2, artery))

		# Thin out the intersection: a random subset reads as worn trajectories,
		# the full set reads as a repainted junction box.
		if not is_bend and node_arcs.size() > max_turns_per_node:
			_shuffle_arcs(node_arcs)
			node_arcs.resize(max_turns_per_node)
		result.append_array(node_arcs)
	return result

func _lane_pairs(data : MapData, center : Vector2, d1 : Vector2, d2 : Vector2,
		e1 : int, e2 : int, radius : float, is_bend : bool) -> Array[Array]:
	# Lane o1 joins lane -o1: with d1 and d2 both pointing AWAY from the node,
	# that mapping keeps each lane on the same side of the roadway. It yields one
	# arc per lane, from the tight inner corner to the wide outer sweep, instead
	# of collapsing every lane onto the innermost trajectory.
	var perp1 : Vector2 = Vector2(-d1.y, d1.x)
	var perp2 : Vector2 = Vector2(-d2.y, d2.x)
	var margin1 : float = data.edge_width_px(e1) * 0.5 + radius
	var margin2 : float = data.edge_width_px(e2) * 0.5 + radius
	var offsets1 : PackedFloat32Array = _lane_offsets(data, data.edge_is_artery[e1])
	var offsets2 : PackedFloat32Array = _lane_offsets(data, data.edge_is_artery[e2])

	var pairs : Array[Array] = []
	for o1 : float in offsets1:
		if not is_bend and _rng.randf() > turn_chance:
			continue
		var o2 : float = _nearest_offset(offsets2, -o1)
		pairs.append([
			center + d1 * margin2 + perp1 * o1,
			center + d2 * margin1 + perp2 * o2,
		])
	return pairs

func _shuffle_arcs(values : Array[Dictionary]) -> void:
	# Fisher-Yates on the seeded rng: Array.shuffle() uses the global one and
	# would break determinism.
	for i : int in range(values.size() - 1, 0, -1):
		var j : int = _rng.randi_range(0, i)
		var tmp : Dictionary = values[i]
		values[i] = values[j]
		values[j] = tmp

func _nearest_offset(offsets : PackedFloat32Array, target : float) -> float:
	# Handles a bend between roads of different lane counts
	var best : float = 0.0
	var best_dist : float = INF
	for o : float in offsets:
		var dist : float = absf(o - target)
		if dist < best_dist:
			best_dist = dist
			best = o
	return best


func _make_arc(p0 : Vector2, p1 : Vector2, d1 : Vector2, d2 : Vector2, artery : bool) -> Dictionary:
	# Both handles aim at the intersection of the two lane axes: clean quarter circle
	var corner : Vector2 = _axes_intersection(p0, d1, p1, d2)
	return {
		"points": PackedVector2Array([p0, p1]),
		"handles": PackedVector2Array([
			(corner - p0) * BEZIER_CIRCLE_K,
			(corner - p1) * BEZIER_CIRCLE_K,
		]),
		"artery": artery,
	}


func _axes_intersection(p0 : Vector2, d1 : Vector2, p1 : Vector2, d2 : Vector2) -> Vector2:
	# d1 and d2 are perpendicular and axis-aligned: the corner is simply the
	# mix of both components
	if absf(d1.x) > 0.5:
		return Vector2(p1.x, p0.y)
	return Vector2(p0.x, p1.y)


func _edge_dir_from(data : MapData, edge_idx : int, node_idx : int) -> Vector2:
	var edge : Vector2i = data.edges[edge_idx]
	var other : int = edge.y if edge.x == node_idx else edge.x
	return (data.nodes[other] - data.nodes[node_idx]).normalized()


# =================================================================
# STRAIGHT RUNS (maximal collinear chains of same-type edges)
# =================================================================
func _straight_runs(data : MapData) -> Array[Dictionary]:
	var px : float = float(data.cell_size)
	var used : Array[bool] = []
	used.resize(data.edges.size())
	used.fill(false)

	var incident : Array = []
	incident.resize(data.nodes.size())
	for n : int in data.nodes.size():
		incident[n] = []
	for e : int in data.edges.size():
		incident[data.edges[e].x].append(e)
		incident[data.edges[e].y].append(e)

	var runs : Array[Dictionary] = []
	for e : int in data.edges.size():
		if used[e]:
			continue
		used[e] = true
		var artery : bool = data.edge_is_artery[e]
		var start : int = _walk(data, incident, used, data.edges[e].x, data.edges[e].y, artery)
		var stop : int = _walk(data, incident, used, data.edges[e].y, data.edges[e].x, artery)
		runs.append({
			"from": data.nodes[start] * px,
			"to": data.nodes[stop] * px,
			"from_node": start,
			"to_node": stop,
			"artery": artery,
		})
	return runs


func _walk(data : MapData, incident : Array, used : Array[bool], from_node : int, prev_node : int, artery : bool) -> int:
	var dir : Vector2i = _dir_sign(data.nodes[prev_node], data.nodes[from_node])
	var current : int = from_node
	var extended : bool = true
	while extended:
		extended = false
		for e : int in incident[current]:
			if used[e] or data.edge_is_artery[e] != artery:
				continue
			var other : int = data.edges[e].y if data.edges[e].x == current else data.edges[e].x
			if _dir_sign(data.nodes[current], data.nodes[other]) == dir:
				used[e] = true
				current = other
				extended = true
				break
	return current


func _dir_sign(from_pos : Vector2, to_pos : Vector2) -> Vector2i:
	return Vector2i(signi(int(to_pos.x - from_pos.x)), signi(int(to_pos.y - from_pos.y)))


# =================================================================
# SPAWN
# =================================================================
func _spawn_path(points : PackedVector2Array, artery : bool, handles : PackedVector2Array = PackedVector2Array(), is_turn : bool = false) -> void:
	var template : PackedScene = null
	if is_turn:
		template = artery_turn_template if artery else street_turn_template
	if template == null:
		template = artery_template if artery else street_template
	if template == null:
		template = street_template
	var path : Path2D = template.instantiate() as Path2D
	if path == null:
		push_error("[MapRoadPaths] template root must be a Path2D")
		return

	var curve : Curve2D = Curve2D.new()
	for i : int in points.size():
		var handle_in : Vector2 = Vector2.ZERO
		var handle_out : Vector2 = Vector2.ZERO
		if handles.size() == points.size():
			# Two-point bezier: first point uses its out handle, last its in handle
			if i == 0:
				handle_out = handles[i]
			else:
				handle_in = handles[i]
		elif points.size() > 2:
			# Catmull-Rom style tangents: keeps the wandering lane smooth
			var previous : Vector2 = points[maxi(i - 1, 0)]
			var following : Vector2 = points[mini(i + 1, points.size() - 1)]
			var tangent : Vector2 = (following - previous) * 0.25
			handle_in = -tangent
			handle_out = tangent
		curve.add_point(points[i], handle_in, handle_out)

	path.curve = curve                      # set BEFORE add_child so the tool's _ready sees it
	if use_map_seed:
		path.set("rng_seed", int(_rng.randi()))  # no-op if the template has no rng_seed
	add_child(path)
	_built += 1

func _count_descendants(node : Node) -> int:
	var total : int = 0
	for child : Node in node.get_children():
		total += 1 + _count_descendants(child)
	return total

func _cross_half_width(data : MapData, node_index : int, dir : Vector2) -> float:
	# Half width of the WIDEST road crossing this approach: the same reference
	# the turn arcs use for their start offset. Returns 0 at a border stub, so
	# the lane then runs all the way to the node.
	var widest : float = 0.0
	for i : int in data.edges.size():
		var edge : Vector2i = data.edges[i]
		var other : int = -1
		if edge.x == node_index:
			other = edge.y
		elif edge.y == node_index:
			other = edge.x
		else:
			continue
		var branch : Vector2 = (data.nodes[other] - data.nodes[node_index]).normalized()
		if absf(branch.dot(dir)) < 0.5:  # perpendicular branch
			widest = maxf(widest, data.edge_width_px(i))
	return widest * 0.5
