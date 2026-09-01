extends Node2D
class_name MapRoadCracks
## Scatters CrackNetworkGenerator instances over the road surface.
## Runs AFTER the road paths / markings pass so cracks read as the topmost wear
## layer, and bakes itself for the same reason MapRoadPaths does: the generator
## emits one draw_rect per virtual pixel.

## Scene whose root is a CrackNetworkGenerator (with its DrawSurface child)
@export var crack_scene : PackedScene = null
@export var profiles : Array[CrackData] = []

@export_group("Density")
## Cracks per 100 road cells. 96x80 map -> roughly 2000 road cells.
@export var density_per_100_cells : float = 1.2
## Minimum distance between two crack origins, in cells
@export var min_distance_cells : int = 5

@export_group("Baking")
@export var bake_to_texture : bool = true
@export var free_sources_after_bake : bool = true

var _data : MapData = null
var _rng : RandomNumberGenerator = RandomNumberGenerator.new()
var _placed : Array[Vector2] = []
var _edge_cumulative : PackedFloat32Array = PackedFloat32Array()
var _edge_total : float = 0.0
var _live_holder : Node2D = null

func build(data : MapData) -> void:
	for child : Node in get_children():
		child.queue_free()
	_placed.clear()
	_data = data

	if crack_scene == null:
		push_error("[MapRoadCracks] no crack_scene assigned")
		return
	if profiles.is_empty():
		print("[MapRoadCracks] no profile: pass skipped")
		return

	_rng.seed = data.seed_used ^ 0xC4AC5  # own stream
	# Pulsing cracks live here: this node is kept out of the bake so its tween
	# can keep running.
	_live_holder = Node2D.new()
	_live_holder.name = "LiveCracks"
	add_child(_live_holder)
	_build_edge_table()

	var road_cells : int = _count_road_cells()
	var target : int = int(round(float(road_cells) * density_per_100_cells / 100.0))
	var min_dist_sq : float = pow(float(min_distance_cells) * float(data.cell_size), 2.0)
	var built : int = 0

	for attempt : int in target * 4:
		if built >= target:
			break
		var profile : CrackData = _pick_profile()
		if profile == null:
			break
		var spot : Array = _pick_spot(profile)
		if spot.is_empty():
			continue
		var position_px : Vector2 = spot[0]
		if not _is_far_enough(position_px, min_dist_sq):
			continue
		_spawn(profile, position_px, float(spot[1]))
		_placed.append(position_px)
		built += 1

	print("[MapRoadCracks] built ", built, " cracks over ", road_cells, " road cells")

	if bake_to_texture:
		_bake(Vector2i(_data.map_size_cells) * _data.cell_size)


# =================================================================
# PLACEMENT
# =================================================================
func _count_road_cells() -> int:
	var total : int = 0
	for i : int in _data.cells.size():
		var type : int = _data.cells[i]
		if type == MapData.CellType.STREET or type == MapData.CellType.ARTERY:
			total += 1
	return total


func _build_edge_table() -> void:
	# Cumulative edge lengths, so a random draw lands on a road proportionally
	# to its length instead of favouring the short ones.
	var px : float = float(_data.cell_size)
	_edge_cumulative.resize(_data.edges.size())
	_edge_total = 0.0
	for i : int in _data.edges.size():
		var edge : Vector2i = _data.edges[i]
		_edge_total += (_data.nodes[edge.x] - _data.nodes[edge.y]).length() * px
		_edge_cumulative[i] = _edge_total


func _pick_edge() -> int:
	if _edge_total <= 0.0:
		return -1
	var roll : float = _rng.randf() * _edge_total
	for i : int in _edge_cumulative.size():
		if roll <= _edge_cumulative[i]:
			return i
	return _edge_cumulative.size() - 1


## Returns [position_px, angle_degrees], or [] when no valid spot was found
func _pick_spot(profile : CrackData) -> Array:
	var px : float = float(_data.cell_size)

	if _rng.randf() < profile.intersection_ratio:
		# Intersection: alligator cracking, no dominant direction
		var node_index : int = _rng.randi() % _data.nodes.size()
		var center : Vector2 = _data.nodes[node_index] * px
		var spread : float = 2.0 * px
		var offset : Vector2 = Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(-spread, spread))
		return [center + offset, _rng.randf() * 360.0]

	var edge_index : int = _pick_edge()
	if edge_index == -1:
		return []
	var edge : Vector2i = _data.edges[edge_index]
	var a : Vector2 = _data.nodes[edge.x] * px
	var b : Vector2 = _data.nodes[edge.y] * px
	var dir : Vector2 = (b - a).normalized()
	var perp : Vector2 = Vector2(-dir.y, dir.x)

	# Stay clear of the intersections and of the road edge
	var half_width : float = _data.edge_width_px(edge_index) * 0.5 - profile.edge_margin_px
	if half_width <= 0.0:
		return []
	var length : float = a.distance_to(b)
	var end_margin : float = minf(length * 0.15, 3.0 * px)
	if length - end_margin * 2.0 <= 0.0:
		return []

	var along : float = _rng.randf_range(end_margin, length - end_margin)
	var lateral : float = _rng.randf_range(-half_width, half_width)
	var position_px : Vector2 = a + dir * along + perp * lateral

	var base_angle : float = rad_to_deg(dir.angle())
	match profile.orientation:
		CrackData.Orientation.ACROSS_ROAD:
			base_angle += 90.0
		CrackData.Orientation.RANDOM:
			base_angle = _rng.randf() * 360.0
	base_angle += _rng.randf_range(-profile.angle_jitter_degrees, profile.angle_jitter_degrees)
	return [position_px, base_angle]


func _is_far_enough(position_px : Vector2, min_dist_sq : float) -> bool:
	for other : Vector2 in _placed:
		if position_px.distance_squared_to(other) < min_dist_sq:
			return false
	return true


func _pick_profile() -> CrackData:
	var total : float = 0.0
	for profile : CrackData in profiles:
		if profile != null:
			total += maxf(profile.weight, 0.0)
	if total <= 0.0:
		return null
	var roll : float = _rng.randf() * total
	for profile : CrackData in profiles:
		if profile == null:
			continue
		roll -= maxf(profile.weight, 0.0)
		if roll <= 0.0:
			return profile
	return profiles[profiles.size() - 1]


# =================================================================
# SPAWN
# =================================================================
func _spawn(profile : CrackData, position_px : Vector2, angle_degrees : float) -> void:
	var scene : PackedScene = profile.crack_scene if profile.crack_scene != null else crack_scene
	if scene == null:
		push_error("[MapRoadCracks] no crack scene for profile '%s'" % profile.name)
		return
	var crack : Node2D = scene.instantiate() as Node2D
	if crack == null:
		push_error("[MapRoadCracks] crack scene root must be a Node2D")
		return

	# set() rather than typed assignment: the two generators share most property
	# names and each silently ignores the ones it does not declare.
	# Configured BEFORE add_child: every setter calls generate(), which returns
	# immediately outside the tree. _ready() then generates once.
	crack.position = position_px
	crack.set("start_position", Vector2.ZERO)
	crack.set("start_angle_degrees", angle_degrees)
	crack.set("pixel_size", profile.pixel_size)
	crack.set("total_length", _rng.randi_range(profile.total_length.x, profile.total_length.y))
	crack.set("segment_length", _rng.randi_range(profile.segment_length.x, profile.segment_length.y))
	crack.set("max_turn_degrees", _rng.randf_range(profile.max_turn_degrees.x, profile.max_turn_degrees.y))
	crack.set("turn_smoothing", profile.turn_smoothing)

	# thickness_max first: the two setters clamp against each other
	crack.set("thickness_max", profile.thickness.y)
	crack.set("thickness_min", profile.thickness.x)
	crack.set("thickness_variation_step", profile.thickness_variation_step)

	crack.set("branch_chance", _rng.randf_range(profile.branch_chance.x, profile.branch_chance.y))
	crack.set("branch_chance_falloff", profile.branch_chance_falloff)
	crack.set("branch_length_ratio", profile.branch_length_ratio)
	crack.set("branch_angle_spread_degrees", profile.branch_angle_spread_degrees)
	crack.set("max_branch_depth", _rng.randi_range(profile.max_branch_depth.x, profile.max_branch_depth.y))
	crack.set("thickness_falloff_per_depth", profile.thickness_falloff_per_depth)

	var pulsing : bool = _rng.randf() < profile.pulse_ratio
	if pulsing:
		crack.set("crack_color", profile.pulse_color_low)
	else:
		var color : Color = profile.color
		color.a = clampf(color.a + _rng.randf_range(-profile.alpha_jitter, profile.alpha_jitter), 0.0, 1.0)
		crack.set("crack_color", color)
	crack.set("rng_seed", int(_rng.randi()))

	if not pulsing:
		add_child(crack)
		return

	_live_holder.add_child(crack)
	var pulse : CrackPulse = CrackPulse.new()
	pulse.color_low = profile.pulse_color_low
	pulse.color_high = profile.pulse_color_high
	pulse.duration = _rng.randf_range(profile.pulse_duration.x, profile.pulse_duration.y)
	pulse.start_delay = _rng.randf_range(profile.pulse_start_delay.x, profile.pulse_start_delay.y)
	crack.add_child(pulse)


# =================================================================
# BAKING
# =================================================================
func _bake(size_px : Vector2i) -> void:
	# Same technique as MapRoadPaths: the generator emits one draw_rect per
	# virtual pixel, which is fine once and ruinous every frame.
	
	
	var holder : Node2D = Node2D.new()
	holder.name = "BakeSource"
	var sources : Array[Node] = []
	for child : Node in get_children():
		if child == _live_holder:
			continue
		sources.append(child)
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

	await RenderingServer.frame_post_draw

	var sprite : Sprite2D = Sprite2D.new()
	sprite.name = "BakedCracks"
	sprite.texture = viewport.get_texture()
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

	if free_sources_after_bake:
		holder.queue_free()
		# The baked sprite was added last, so it would cover the live cracks
	if _live_holder != null and is_instance_valid(_live_holder):
		move_child(_live_holder, get_child_count() - 1)
	print("[MapRoadCracks] baked cracks into a %s texture" % str(size_px))
