extends Node2D
class_name Afterimage
## Universal afterimage trail: add it as a child of any moving object (saw, projectile, enemy...).
## Copies the source sprite (Sprite2D or AnimatedSprite2D) into pooled ghosts that fade along a gradient.
## Ghosts are created once (no allocation while playing), each with its own material (tint / fade uniforms)

## Sprite2D or AnimatedSprite2D to copy. Empty = the parent if it is a sprite, else the first sprite among its children
@export var source : Node2D
## Can be switched by code (e.g. only while a saw is thrown)
@export var emitting : bool = true
@export var ghost_shader : Shader                  # afterimage_shader.gdshader (tint_color / tint_strength / alpha / fade)
@export var min_speed : float = 60.0              # px/s: slower = no ghost
@export var interval : float = 0.045
@export var lifetime : float = 0.28
## Tint over the ghost life (0 = spawn, 1 = vanished)
@export var tint_gradient : Gradient
@export_range(0.0, 1.0) var tint_strength : float = 0.55
@export_range(0.0, 1.0) var alpha : float = 1.0
## Draw order relative to the source (-1 = just under it)
@export var z_offset : int = -1

var ghosts : Array[Sprite2D] = []
var ghost_materials : Array[ShaderMaterial] = []
var ghost_ages : PackedFloat32Array = PackedFloat32Array()
var next_ghost : int = 0
var cooldown : float = 0.0
var last_position : Vector2 = Vector2.ZERO
var game_paused : bool = false


func _ready() -> void:
	if source == null:
		source = _find_source()
	if source == null or ghost_shader == null:
		push_warning("[Afterimage] no source sprite or no shader under " + str(get_parent().name))
		set_process(false)
		return
	if tint_gradient == null:
		tint_gradient = Gradient.new()
		tint_gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		tint_gradient.colors = PackedColorArray([
			Color(1.0, 0.85, 0.3), Color(1.0, 0.3, 0.4), Color(0.3, 0.3, 0.9)])
	_build_pool()
	last_position = source.global_position
	SignalManager.game_paused.connect(func(paused : bool) -> void: game_paused = paused)


func _process(delta : float) -> void:
	if game_paused or delta <= 0.0:
		return
	_update_ghosts(delta)
	# Speed from the displacement: works for objects moved by code (no velocity needed)
	var current_position : Vector2 = source.global_position
	var speed : float = current_position.distance_to(last_position) / delta
	last_position = current_position
	if !emitting or !source.is_visible_in_tree() or speed < min_speed:
		cooldown = 0.0   # first ghost right away when it moves again
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	cooldown = interval
	_spawn_ghost()


## Pooled objects: call it when the object is reused somewhere else (no ghost from the jump)
func reset() -> void:
	last_position = source.global_position
	cooldown = 0.0


# ---------------- INTERNALS ----------------

func _find_source() -> Node2D:
	var parent : Node = get_parent()
	if parent is Sprite2D or parent is AnimatedSprite2D:
		return parent as Node2D
	for child : Node in parent.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child as Node2D
	return null


## Enough ghosts to cover one lifetime at the spawn rate: the oldest one is reused
func _build_pool() -> void:
	var pool_size : int = ceili(lifetime / interval) + 1
	ghost_ages.resize(pool_size)
	# The source is the parent: its z is already inherited by this node
	# Top level ghosts do not inherit the z of their parents: absolute z of the source, set once
	var ghost_z : int = clampi(_get_absolute_z(source) + z_offset, RenderingServer.CANVAS_ITEM_Z_MIN, RenderingServer.CANVAS_ITEM_Z_MAX)
	for i : int in pool_size:
		var ghost_material : ShaderMaterial = ShaderMaterial.new()
		ghost_material.shader = ghost_shader
		ghost_material.set_shader_parameter("tint_strength", tint_strength)
		ghost_material.set_shader_parameter("alpha", alpha)
		var ghost : Sprite2D = Sprite2D.new()
		ghost.top_level = true   # world space: stays where it spawned while the object moves on
		ghost.material = ghost_material
		ghost.z_as_relative = false
		ghost.z_index = ghost_z
		ghost.hide()
		add_child(ghost)
		ghosts.append(ghost)
		ghost_materials.append(ghost_material)
		ghost_ages[i] = lifetime   # dead until spawned


func _update_ghosts(delta : float) -> void:
	for i : int in ghosts.size():
		if ghost_ages[i] >= lifetime:
			continue
		ghost_ages[i] += delta
		if ghost_ages[i] >= lifetime:
			ghosts[i].hide()
			continue
		var life_ratio : float = ghost_ages[i] / lifetime
		ghost_materials[i].set_shader_parameter("tint_color", tint_gradient.sample(life_ratio))
		ghost_materials[i].set_shader_parameter("fade", 1.0 - life_ratio)


func _spawn_ghost() -> void:
	var texture : Texture2D = _get_source_texture()
	if texture == null:
		return
	var index : int = next_ghost
	next_ghost = (next_ghost + 1) % ghosts.size()
	var ghost : Sprite2D = ghosts[index]
	ghost.texture = texture
	if source is Sprite2D:
		var sprite : Sprite2D = source as Sprite2D
		# Frames grid before the frame index: the frame must exist in the grid
		ghost.hframes = sprite.hframes
		ghost.vframes = sprite.vframes
		ghost.frame = sprite.frame
		ghost.region_enabled = sprite.region_enabled
		ghost.region_rect = sprite.region_rect
		ghost.offset = sprite.offset
		ghost.centered = sprite.centered
		ghost.flip_h = sprite.flip_h
		ghost.flip_v = sprite.flip_v
	else:
		var animated : AnimatedSprite2D = source as AnimatedSprite2D
		# The current frame texture is already cut: no grid, no region
		ghost.hframes = 1
		ghost.vframes = 1
		ghost.frame = 0
		ghost.region_enabled = false
		ghost.offset = animated.offset
		ghost.centered = animated.centered
		ghost.flip_h = animated.flip_h
		ghost.flip_v = animated.flip_v
	ghost.global_transform = source.global_transform
	ghost_materials[index].set_shader_parameter("tint_color", tint_gradient.sample(0.0))
	ghost_materials[index].set_shader_parameter("fade", 1.0)
	ghost_ages[index] = 0.0
	ghost.show()


func _get_source_texture() -> Texture2D:
	if source is Sprite2D:
		return (source as Sprite2D).texture
	var animated : AnimatedSprite2D = source as AnimatedSprite2D
	if animated != null and animated.sprite_frames != null:
		return animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
	return null

## Z index the item is drawn with: its own, plus its parents' while z_as_relative is on
func _get_absolute_z(item : CanvasItem) -> int:
	var absolute_z : int = 0
	var node : Node = item
	while node is CanvasItem:
		var canvas_item : CanvasItem = node as CanvasItem
		absolute_z += canvas_item.z_index
		if !canvas_item.z_as_relative:
			break
		node = node.get_parent()
	return absolute_z
