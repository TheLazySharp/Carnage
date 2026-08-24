class_name MapShadowsGround
extends Node2D
## Single ground-shadow layer for the whole map.
## Building shadows (Building/ShadowsGroup) and cable shadows are reparented
## here by their respective passes, then bake() renders them ONCE into a
## texture and applies the transparency globally.
##
## Why: two separate CanvasItems each at 45% alpha always accumulate, whatever
## the parent modulate is. Applying the alpha once, on the baked result, is the
## only way to get uniform shadows without a per-frame CanvasGroup.
##
## REQUIREMENT: the source shadows must be drawn OPAQUE (alpha 1). Their
## transparency comes from shadow_color below, applied after the bake.

## Final tint and opacity of the whole shadow layer
@export var shadow_color : Color = Color(0.0, 0.0, 0.0, 0.75)
## Uncheck while authoring: sources stay live (and overlaps will accumulate)
@export var bake_enabled : bool = true

var _baked : Sprite2D = null


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
		push_warning("[MapShadowsGround] nothing to bake: check the builder's shadows_ground field and shadow_source_name")
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

	await RenderingServer.frame_post_draw

	_baked = Sprite2D.new()
	_baked.name = "BakedShadows"
	_baked.texture = viewport.get_texture()
	_baked.centered = false
	_baked.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_baked.self_modulate = shadow_color  # the transparency, applied ONCE
	add_child(_baked)

	holder.queue_free()  # the render target keeps the baked image
	print("[MapShadowsGround] baked ", sources.size(), " shadow sources")
