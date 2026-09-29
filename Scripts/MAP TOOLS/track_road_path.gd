class_name TrackRoadPaths
extends Node2D
## Asphalt pass of the speed ring. One CLOSED Path2D per traffic lane, each an
## exact parallel of the centreline (MapData.track_offset_curve), all painted by
## the same brush scene as the city arteries, then baked ONCE into a single
## texture. Replaces MapRoadPaths on the Track: no graph, no turn arcs.

## RoadBrushPath2D scene, the same one the city arteries use
@export var brush_template : PackedScene = null
@export var use_map_seed : bool = true
## Constant random lateral offset per lane, in pixels: breaks the perfect
## parallelism of the brushes
@export var lane_jitter_px : float = 6.0

@export_group("Baking")
## Uncheck while tuning the brush: the lane paths then stay alive as children
@export var bake_to_texture : bool = true

@export_group("Racing groove")
## Heavy-wear brush laid along the racing line through each turn: the main
## visual cue of the banking. Leave empty to skip.
@export var groove_template : PackedScene = null
## Lateral offset on turn entry and exit, in px (> 0 = toward the wall)
@export var groove_high_px : float = 96.0
## Lateral offset at the apex, mid-turn, in px (< 0 = toward the infield)
@export var groove_apex_px : float = -112.0
## Straight run kept high before and after each turn, in px
@export var groove_lead_px : float = 384.0
## Overlapping passes per turn: a single brush reads as a stripe, not a groove
@export_range(1, 6) var groove_passes : int = 2
## Random lateral shift of each pass, in px
@export var groove_jitter_px : float = 24.0

var _build_id : int = 0


func build(data : MapData) -> void:
	_build_id += 1
	var build_id : int = _build_id
	for child : Node in get_children():
		child.queue_free()

	if brush_template == null:
		push_error("[TrackRoadPaths] brush_template is empty")
		return
	if data.track_curve == null:
		push_error("[TrackRoadPaths] no track_curve: run TrackGenerator first")
		return

	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = data.seed_used ^ 0x7A5C  # own stream

	# Paths are spawned straight into the bake viewport: no reparenting
	var target : Node = self
	var viewport : SubViewport = null
	if bake_to_texture:
		viewport = _make_viewport(Vector2i(data.map_size_cells) * data.cell_size)
		add_child(viewport)
		target = viewport

	var lane_w : float = float(data.lane_width_px)
	var lanes : int = data.artery_lanes
	for i : int in lanes:
		var offset : float = (float(i) - float(lanes - 1) * 0.5) * lane_w
		offset += rng.randf_range(-lane_jitter_px, lane_jitter_px)
		_spawn_brush(target, brush_template, data.track_offset_curve(offset), rng)

	# Racing groove, one closed loop per pass, spawned AFTER the lanes so it
	# renders on top of them
	var grooves : int = 0
	if groove_template != null:
		for _pass : int in groove_passes:
			var shift : float = rng.randf_range(-groove_jitter_px, groove_jitter_px)
			var points : PackedVector2Array = data.track_groove_loop(
					groove_high_px + shift, groove_apex_px + shift)
			_spawn_brush(target, groove_template, _polyline_curve(points), rng)
			grooves += 1
	print("[TrackRoadPaths] ", lanes, " lanes + ", grooves, " grooves | lap ",
			int(data.lap_length_px), " px")

	if viewport == null:
		return

	# Re-arm AFTER add_child, then give the brushes one full frame to render
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	# A regeneration (T) during the await already queued this viewport for free
	if build_id != _build_id or not is_instance_valid(viewport):
		return

	# Read back to a plain texture: never keep a 3072x2560 render target alive
	var image : Image = viewport.get_texture().get_image()
	viewport.queue_free()  # takes the lane paths with it

	var sprite : Sprite2D = Sprite2D.new()
	sprite.name = "BakedTrack"
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = ImageTexture.create_from_image(image)
	add_child(sprite)
	print("[TrackRoadPaths] baked ", image.get_size())


func _make_viewport(size_px : Vector2i) -> SubViewport:
	var viewport : SubViewport = SubViewport.new()
	viewport.name = "BakeViewport"
	viewport.size = size_px
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return viewport


func _spawn_brush(target : Node, template : PackedScene, curve : Curve2D,
		rng : RandomNumberGenerator) -> void:
	var path : Path2D = template.instantiate() as Path2D
	if path == null:
		push_error("[TrackRoadPaths] template root must be a Path2D")
		return
	path.curve = curve  # set BEFORE add_child so the tool's _ready sees it
	if use_map_seed:
		# Mixed into the wear seed by RoadBrushPath2D: every path gets its own pattern
		path.set("rng_seed", int(rng.randi()))
	target.add_child(path)


func _polyline_curve(points : PackedVector2Array) -> Curve2D:
	var curve : Curve2D = Curve2D.new()
	for point : Vector2 in points:
		curve.add_point(point)
	return curve
