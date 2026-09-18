class_name HordeOutline
extends Node2D

## Post-process merging nearby enemies into one silhouette with a single outline.
## SourceViewport renders the living enemy pools with the main camera's view, then:
##   dilate H -> dilate V -> erode H -> erode V  (morphological closing: gaps narrower than 2 * close_radius are filled)
##   -> Display: original enemy pixels, fill_color in the closed gaps, outline_color around the union.

@export var enabled: bool = true: set = set_enabled

@export_group("Clustering")
## Enemies (itself included) needed in the 3x3 cells around an enemy for it to join a mass.
@export var min_cluster_count: int = 5
## A member stays while its neighborhood count >= min_cluster_count - hysteresis (anti flicker).
@export var hysteresis: int = 1
## Grid cell size = largest registered sprite size * this ratio.
@export var cell_size_ratio: float = 0.65
## Extra cells around the visible area.
@export var margin_cells: int = 2
## An enemy knocked back faster than this (px/s) leaves the mass -> it bursts out on impact.
@export var knockback_exclusion_speed: float = 120.0

@export_group("Shaders")
## Separable dilate / erode pass (morph_pass.gdshader).
@export var morph_shader: Shader = null
## Compositing (outline_final.gdshader).
@export var final_shader: Shader = null

@export_group("Look")
## Gaps narrower than 2 * close_radius (px) between enemies are filled.
@export_range(1, 32) var close_radius: int = 8: set = set_close_radius
@export var fill_color: Color = Color.BLACK: set = set_fill_color
@export var outline_color: Color = Color.WHITE: set = set_outline_color
@export_range(0, 4) var outline_width: int = 1: set = set_outline_width
## Sprite pixels close to this color stay visible inside the mass (the eyes).
@export var eye_color: Color = Color(1.0, 0.0, 0.0, 1.0): set = set_eye_color
@export_range(0.0, 1.0, 0.01) var eye_tolerance: float = 0.3: set = set_eye_tolerance
## Sprite pixels at least this bright stay visible (white damage flash).
@export_range(0.0, 1.0, 0.01) var flash_min_brightness: float = 0.95: set = set_flash_min_brightness

@export_group("Debug")
## Shows the closed mask (red) and the raw enemy mask (green) instead of the final render.
@export var show_mask: bool = false: set = set_show_mask

const PASS_COUNT: int = 4

@onready var source_viewport: SubViewport = $SourceViewport
@onready var display: Sprite2D = $Display

var pass_viewports: Array[SubViewport] = []
var pass_materials: Array[ShaderMaterial] = []
var display_material: ShaderMaterial = null
var current_size: Vector2i = Vector2i.ZERO
@onready var pools_root: Node2D = $SourceViewport/PoolsRoot

var camera: Camera2D = null
var cell_size: float = 32.0
var inverse_cell_size: float = 1.0 / 32.0
var reference_sprite_size: float = 0.0
var grid_dirty: bool = true
var grid_width: int = 0
var grid_height: int = 0
var grid_origin: Vector2 = Vector2.ZERO
var counts: PackedInt32Array = PackedInt32Array()
var knockback_exclusion_speed_squared: float = 0.0

func _ready() -> void:
	if morph_shader == null or final_shader == null:
		push_error("HordeOutline : morph_shader / final_shader non assignés")
		return
	var main_viewport: Viewport = get_viewport()

	source_viewport.transparent_bg = true
	source_viewport.disable_3d = true
	source_viewport.gui_disable_input = true
	source_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	source_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	source_viewport.snap_2d_transforms_to_pixel = main_viewport.snap_2d_transforms_to_pixel
	source_viewport.snap_2d_vertices_to_pixel = main_viewport.snap_2d_vertices_to_pixel

	build_chain()

	display_material = ShaderMaterial.new()
	display_material.shader = final_shader
	display_material.set_shader_parameter("closed_mask", pass_viewports[PASS_COUNT - 1].get_texture())
	display.centered = false
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.texture = source_viewport.get_texture()
	display.material = display_material
	apply_look()

	resize_to_screen(Vector2i(main_viewport.get_visible_rect().size))
	# Runs after every _process / camera update, right before rendering
	RenderingServer.frame_pre_draw.connect(sync_view)
	knockback_exclusion_speed_squared = knockback_exclusion_speed * knockback_exclusion_speed
	set_enabled(enabled)

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(sync_view):
		RenderingServer.frame_pre_draw.disconnect(sync_view)


## Source -> H distance -> V disc test (dilated) -> H distance on the complement -> V disc test inverted (closed).
func build_chain() -> void:
	var input_texture: Texture2D = source_viewport.get_texture()
	for i: int in range(PASS_COUNT):
		var pass_viewport: SubViewport = SubViewport.new()
		pass_viewport.name = "DiscMorphPass%d" % i
		pass_viewport.transparent_bg = false
		pass_viewport.disable_3d = true
		pass_viewport.gui_disable_input = true
		pass_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		pass_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		add_child(pass_viewport)

		var pass_material: ShaderMaterial = ShaderMaterial.new()
		pass_material.shader = morph_shader
		pass_material.set_shader_parameter("pass_type", i)
		pass_material.set_shader_parameter("radius", close_radius)

		var quad: Sprite2D = Sprite2D.new()
		quad.centered = false
		quad.texture = input_texture
		quad.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		quad.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		quad.material = pass_material
		pass_viewport.add_child(quad)

		pass_viewports.append(pass_viewport)
		pass_materials.append(pass_material)
		input_texture = pass_viewport.get_texture()


## Copies the main camera view into the source viewport and pins the display to the screen.
func sync_view() -> void:
	var main_viewport: Viewport = get_viewport()
	if main_viewport == null:
		return
	var screen_size: Vector2i = Vector2i(main_viewport.get_visible_rect().size)
	if screen_size != current_size:
		resize_to_screen(screen_size)
	var view_transform: Transform2D = main_viewport.canvas_transform
	source_viewport.canvas_transform = view_transform
	display.global_transform = view_transform.affine_inverse()


func resize_to_screen(screen_size: Vector2i) -> void:
	if screen_size.x <= 0 or screen_size.y <= 0:
		return
	current_size = screen_size
	source_viewport.size = screen_size
	for pass_viewport: SubViewport in pass_viewports:
		pass_viewport.size = screen_size

# ─────────────────────────────────────────────
#  Membership grid — called by EnemiesMultiMeshRenderer / EnemyTypePool at each render step
# ─────────────────────────────────────────────

## Called by each pool at creation. The grid resolution follows the largest sprite.
func register_sprite_size(sprite_size: Vector2) -> void:
	var largest: float = maxf(sprite_size.x, sprite_size.y)
	if largest <= reference_sprite_size:
		return
	reference_sprite_size = largest
	cell_size = maxf(8.0, roundf(largest * cell_size_ratio))
	inverse_cell_size = 1.0 / cell_size
	grid_dirty = true


## Recenter the grid on the camera and clear the counts. Returns false if nothing can be done this step.
func begin_step() -> bool:
	if camera == null:
		camera = get_viewport().get_camera_2d()
		if camera == null:
			return false
	var view_size: Vector2 = get_viewport_rect().size / camera.zoom
	var needed_width: int = int(ceil(view_size.x * inverse_cell_size)) + margin_cells * 2
	var needed_height: int = int(ceil(view_size.y * inverse_cell_size)) + margin_cells * 2
	if grid_dirty or needed_width != grid_width or needed_height != grid_height:
		grid_width = needed_width
		grid_height = needed_height
		grid_dirty = false
		counts.resize(grid_width * grid_height)
	var camera_center: Vector2 = camera.get_screen_center_position()
	grid_origin = (camera_center * inverse_cell_size - Vector2(grid_width, grid_height) * 0.5).floor() * cell_size
	counts.fill(0)
	return true


## Pass 1: every candidate enemy adds itself to its cell.
func add_count(world_position: Vector2) -> void:
	var cell_x: int = int((world_position.x - grid_origin.x) * inverse_cell_size)
	var cell_y: int = int((world_position.y - grid_origin.y) * inverse_cell_size)
	if cell_x < 1 or cell_y < 1 or cell_x >= grid_width - 1 or cell_y >= grid_height - 1:
		return
	counts[cell_y * grid_width + cell_x] += 1


## Pass 2: true if the enemy belongs to a mass (>= min_cluster_count enemies in its 3x3 cells, with hysteresis).
func resolve(world_position: Vector2, was_member: bool) -> bool:
	var cell_x: int = int((world_position.x - grid_origin.x) * inverse_cell_size)
	var cell_y: int = int((world_position.y - grid_origin.y) * inverse_cell_size)
	if cell_x < 1 or cell_y < 1 or cell_x >= grid_width - 1 or cell_y >= grid_height - 1:
		return false
	var index: int = cell_y * grid_width + cell_x
	var up: int = index - grid_width
	var down: int = index + grid_width
	var neighborhood_count: int = (
		counts[up - 1] + counts[up] + counts[up + 1]
		+ counts[index - 1] + counts[index] + counts[index + 1]
		+ counts[down - 1] + counts[down] + counts[down + 1]
	)
	var required: int = min_cluster_count - hysteresis if was_member else min_cluster_count
	return neighborhood_count >= required


func set_enabled(value: bool) -> void:
	enabled = value
	if source_viewport == null:
		return   # setter called before _ready
	visible = value
	var update_mode: SubViewport.UpdateMode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	source_viewport.render_target_update_mode = update_mode
	for pass_viewport: SubViewport in pass_viewports:
		pass_viewport.render_target_update_mode = update_mode


func apply_look() -> void:
	set_close_radius(close_radius)
	set_fill_color(fill_color)
	set_outline_color(outline_color)
	set_outline_width(outline_width)
	set_eye_color(eye_color)
	set_eye_tolerance(eye_tolerance)
	set_flash_min_brightness(flash_min_brightness)
	set_show_mask(show_mask)


# Setters keep the shaders in sync when values change in the inspector at runtime.
func set_close_radius(value: int) -> void:
	close_radius = value
	for pass_material: ShaderMaterial in pass_materials:
		pass_material.set_shader_parameter("radius", value)

func set_fill_color(value: Color) -> void:
	fill_color = value
	if display_material != null:
		display_material.set_shader_parameter("fill_color", value)

func set_outline_color(value: Color) -> void:
	outline_color = value
	if display_material != null:
		display_material.set_shader_parameter("outline_color", value)

func set_outline_width(value: int) -> void:
	outline_width = value
	if display_material != null:
		display_material.set_shader_parameter("outline_width", value)

func set_show_mask(value: bool) -> void:
	show_mask = value
	if display_material != null:
		display_material.set_shader_parameter("show_mask", value)

func set_eye_color(value: Color) -> void:
	eye_color = value
	if display_material != null:
		display_material.set_shader_parameter("eye_color", value)

func set_eye_tolerance(value: float) -> void:
	eye_tolerance = value
	if display_material != null:
		display_material.set_shader_parameter("eye_tolerance", value)

func set_flash_min_brightness(value: float) -> void:
	flash_min_brightness = value
	if display_material != null:
		display_material.set_shader_parameter("flash_min_brightness", value)
