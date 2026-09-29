class_name TrackRoadLines
extends Node2D
## Markings of the speed ring. No lane line on an oval: only the two edge
## lines, each an exact parallel of the centreline, plus the start/finish line
## laid ACROSS the track at curve offset 0.
## Templates are RoadMarkingPath2D scenes: their `lines` array carries the whole
## look (colour, width, dash, wear). Author each one around offset 0.
## Like the asphalt, the markings are baked ONCE into a single texture: two
## closed lines of a full lap each are far too many live canvas items.

## Inner edge, the apron line (double yellow on real ovals)
@export var inner_template : PackedScene = null
## Outer edge, along the wall (solid white)
@export var outer_template : PackedScene = null
## Start/finish line (thick white band)
@export var start_template : PackedScene = null
## Gap between each edge line and the asphalt border, in pixels
@export var edge_inset_px : float = 16.0
## How far the start line runs past each edge line, in pixels
@export var start_overshoot_px : float = 0.0
@export var use_map_seed : bool = true

@export_group("Baking")
## Uncheck while tuning the templates: the marking paths then stay alive
@export var bake_to_texture : bool = true

var _built : int = 0
var _build_id : int = 0


func build(data : MapData) -> void:
	_build_id += 1
	var build_id : int = _build_id
	for child : Node in get_children():
		child.queue_free()
	_built = 0
	if data.track_curve == null:
		push_error("[TrackRoadLines] no track_curve: run TrackGenerator first")
		return

	# Markings are spawned straight into the bake viewport: no reparenting
	var target : Node = self
	var viewport : SubViewport = null
	if bake_to_texture:
		viewport = _make_viewport(Vector2i(data.map_size_cells) * data.cell_size)
		add_child(viewport)
		target = viewport

	var edge : float = float(data.track_width_px) * 0.5 - edge_inset_px
	_spawn(target, inner_template, data.track_offset_curve(-edge), data.seed_used + 1)
	_spawn(target, outer_template, data.track_offset_curve(edge), data.seed_used + 2)
	_spawn(target, start_template, _start_line_curve(data, edge + start_overshoot_px), data.seed_used + 3)
	print("[TrackRoadLines] built ", _built, " markings")

	if viewport == null:
		return
	if _built == 0:
		viewport.queue_free()  # no template assigned: never keep an empty texture
		return

	# Re-arm AFTER add_child, then give the markings one full frame to render
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	# A regeneration (T) during the await already queued this viewport for free
	if build_id != _build_id or not is_instance_valid(viewport):
		return

	# Read back to a plain texture: never keep a 3072x2560 render target alive
	var image : Image = viewport.get_texture().get_image()
	viewport.queue_free()  # takes the marking paths and all their canvas items with it

	var sprite : Sprite2D = Sprite2D.new()
	sprite.name = "BakedLines"
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = ImageTexture.create_from_image(image)
	add_child(sprite)
	print("[TrackRoadLines] baked ", image.get_size())


func _make_viewport(size_px : Vector2i) -> SubViewport:
	var viewport : SubViewport = SubViewport.new()
	viewport.name = "BakeViewport"
	viewport.size = size_px
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return viewport


func _start_line_curve(data : MapData, half_length : float) -> Curve2D:
	# Offset 0 of the track curve IS the start line: lay a straight segment
	# across the track there, along the curve normal. It also hides the seam
	# where the closed brushes and edge lines meet themselves.
	var start : Vector2 = data.track_curve.sample_baked(0.0)
	var dir : Vector2 = (data.track_curve.sample_baked(32.0) - start).normalized()
	var normal : Vector2 = Vector2(-dir.y, dir.x)
	var curve : Curve2D = Curve2D.new()
	curve.add_point(start - normal * half_length)
	curve.add_point(start + normal * half_length)
	return curve


func _spawn(target : Node, template : PackedScene, curve : Curve2D, line_seed : int) -> void:
	if template == null:
		return
	var path : Path2D = template.instantiate() as Path2D
	if path == null:
		push_error("[TrackRoadLines] template root must be a Path2D (RoadMarkingPath2D)")
		return
	path.curve = curve  # set BEFORE add_child so the tool's _ready sees it
	if use_map_seed:
		# The line resources are SHARED between instances: the tool reads the
		# seed in its _ready, so it must be written right before add_child
		var lines : Variant = path.get("lines")
		if lines != null:
			for line : Resource in lines:
				if line != null and "line_seed" in line:
					line.line_seed = line_seed
	target.add_child(path)
	_built += 1
