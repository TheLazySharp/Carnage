class_name MapShadowsGround
extends Node2D
## Single ground-shadow layer for the whole map.
## Building shadows (Building/ShadowsGroup) and cable shadows are reparented
## here by their respective passes, then bake() renders them ONCE into a
## texture and applies the transparency globally.
##
## REQUIREMENT: the source shadows must be drawn OPAQUE (alpha 1). Their
## transparency comes from shadow_color below, applied after the bake.

## Final tint and opacity of the whole shadow layer
@export var shadow_color : Color = Color(0.0, 0.0, 0.0, 0.45)
## Uncheck while authoring: sources stay live (and overlaps will accumulate)
@export var bake_enabled : bool = true

var _baked : Sprite2D = null
var _image : Image = null

## Called by the placement passes for each shadow node to collect.
## Keeps the node's world position.
func collect(shadow : Node2D) -> void:
	shadow.reparent(self, true)


func clear_shadows() -> void:
	for child : Node in get_children():
		child.queue_free()
	_baked = null


## Call once, after every pass that adds shadows (buildings, cables...)
func bake(size_px : Vector2i) -> void:
	if not bake_enabled:
		self_modulate = shadow_color
		return

	self_modulate = Color.WHITE  # sources render opaque inside the viewport
	var holder : Node2D = Node2D.new()
	holder.name = "BakeSource"
	var sources : Array[Node] = get_children()
	if sources.is_empty():
		return
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

	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	# Read back once, then drop the render target: keeping several 3072x2560
	# render targets alive is what starves the GPU. An ImageTexture costs the
	# same VRAM as the pixels alone, with no attached framebuffer.
	_image = viewport.get_texture().get_image()
	var used : Rect2i = _image.get_used_rect()
	viewport.queue_free()

	_baked = Sprite2D.new()
	_baked.name = "BakedShadows"
	_baked.texture = ImageTexture.create_from_image(_image)
	_baked.centered = false
	_baked.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_baked.self_modulate = shadow_color
	add_child(_baked)

	holder.queue_free()
	print("[MapShadowsGround] '", name, "' baked ", sources.size(),
			" sources | used rect = ", used)


## Clears from this layer every pixel already covered by `other`. Two baked
## layers drawn on top of each other would otherwise accumulate their alpha:
## 0.745 over 0.745 reads as 0.93, which is the darker patch you see where a
## high shadow crosses a low one.
func subtract_layer(other : MapShadowsGround) -> void:
	if _image == null or other == null or other._image == null:
		return
	var blank : Image = Image.create(_image.get_width(), _image.get_height(), false, _image.get_format())
	blank.fill(Color(0.0, 0.0, 0.0, 0.0))
	# blit_rect_mask copies src into self wherever the mask alpha is non-zero
	_image.blit_rect_mask(blank, other._image, Rect2i(Vector2i.ZERO, _image.get_size()), Vector2i.ZERO)
	if _baked != null:
		_baked.texture = ImageTexture.create_from_image(_image)


## Called once compositing is done. RGB is unused (the tint comes from
## shadow_color), so LA8 halves the VRAM of every layer.
func finalize_bake() -> void:
	if _image != null:
		_image.convert(Image.FORMAT_LA8)
		if _baked != null:
			_baked.texture = ImageTexture.create_from_image(_image)
	_image = null
