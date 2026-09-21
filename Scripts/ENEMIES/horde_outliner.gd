class_name HordeOutline
extends Node2D

## Enemies that belong to a dense pack ("mass") are rendered by their pool's mass twin inside SourceViewport,
## with the main camera's view. Display shows that render through the final shader: opaque pixels become
## fill_color (eyes and damage flash kept), and opaque pixels touching transparency become one peripheral outline.
## Membership is decided on a coarse world-space grid: an enemy joins a mass when at least min_cluster_count
## enemies (itself included) stand in the 3x3 cells around it.

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
## Compositing (outline_final.gdshader).
@export var final_shader: Shader = null
## Hole filling pass (mass_holes.gdshader).
@export var hole_shader: Shader = null

@export_group("Look")
@export var fill_color: Color = Color.BLACK: set = set_fill_color
@export var outline_color: Color = Color.WHITE: set = set_outline_color
## Outline thickness in pixels.
@export_range(0, 4) var outline_width: int = 1: set = set_outline_width
## false = outline drawn inside the sprite footprint (shape unchanged), true = drawn outside around the union.
@export var outline_outside: bool = false: set = set_outline_outside
## Transparent pockets enclosed by sprites within this many pixels in all 8 directions are filled. 0 = off.
@export_range(0, 32) var hole_max_size: int = 12: set = set_hole_max_size
## Sprite pixels close to this color stay visible inside the mass (the eyes).
@export var eye_color: Color = Color(1.0, 0.0, 0.0, 1.0): set = set_eye_color
@export_range(0.0, 1.0, 0.01) var eye_tolerance: float = 0.3: set = set_eye_tolerance
## Sprite pixels at least this bright stay visible (white damage flash).
@export_range(0.0, 1.0, 0.01) var flash_min_brightness: float = 0.95: set = set_flash_min_brightness

@export_group("Debug")
## Shows the raw opaque mask instead of the final render.
@export var show_mask: bool = false: set = set_show_mask

@onready var source_viewport: SubViewport = $SourceViewport
@onready var pools_root: Node2D = $SourceViewport/PoolsRoot
@onready var display: Sprite2D = $Display

var display_material: ShaderMaterial = null
var current_size: Vector2i = Vector2i.ZERO
var hole_viewport: SubViewport = null
var hole_material: ShaderMaterial = null

# Membership grid
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
	if final_shader == null or hole_shader == null:
		push_error("HordeOutline : final_shader / hole_shader non assignés")
		return
	var main_viewport: Viewport = get_viewport()

	source_viewport.transparent_bg = true
	source_viewport.disable_3d = true
	source_viewport.gui_disable_input = true
	source_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	source_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	source_viewport.snap_2d_transforms_to_pixel = main_viewport.snap_2d_transforms_to_pixel
	source_viewport.snap_2d_vertices_to_pixel = main_viewport.snap_2d_vertices_to_pixel

	build_hole_pass()

	display_material = ShaderMaterial.new()
	display_material.shader = final_shader
	display_material.set_shader_parameter("filled_mask", hole_viewport.get_texture())
	display.centered = false
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.texture = source_viewport.get_texture()
	display.material = display_material
	apply_look()

	knockback_exclusion_speed_squared = knockback_exclusion_speed * knockback_exclusion_speed
	resize_to_screen(Vector2i(main_viewport.get_visible_rect().size))
	# Runs after every _process / camera update, right before rendering
	RenderingServer.frame_pre_draw.connect(sync_view)
	set_enabled(enabled)


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(sync_view):
		RenderingServer.frame_pre_draw.disconnect(sync_view)

## One SubViewport drawing the source render through the hole shader -> mass footprint mask.
func build_hole_pass() -> void:
	hole_viewport = SubViewport.new()
	hole_viewport.name = "HolePass"
	hole_viewport.transparent_bg = false
	hole_viewport.disable_3d = true
	hole_viewport.gui_disable_input = true
	hole_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	hole_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(hole_viewport)

	hole_material = ShaderMaterial.new()
	hole_material.shader = hole_shader
	hole_material.set_shader_parameter("hole_max_size", hole_max_size)

	var quad: Sprite2D = Sprite2D.new()
	quad.centered = false
	quad.texture = source_viewport.get_texture()
	quad.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	quad.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	quad.material = hole_material
	hole_viewport.add_child(quad)
	
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
	if hole_viewport != null:
		hole_viewport.size = screen_size


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


# ─────────────────────────────────────────────
#  Look — setters keep the shader in sync when values change in the inspector at runtime
# ─────────────────────────────────────────────

func apply_look() -> void:
	set_fill_color(fill_color)
	set_outline_color(outline_color)
	set_outline_width(outline_width)
	set_outline_outside(outline_outside)
	set_eye_color(eye_color)
	set_eye_tolerance(eye_tolerance)
	set_flash_min_brightness(flash_min_brightness)
	set_show_mask(show_mask)


func set_param(param_name: String, value: Variant) -> void:
	if display_material != null:
		display_material.set_shader_parameter(param_name, value)


func set_enabled(value: bool) -> void:
	enabled = value
	if source_viewport == null:
		return   # setter called before _ready
	visible = value
	var update_mode: SubViewport.UpdateMode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	source_viewport.render_target_update_mode = update_mode
	if hole_viewport != null:
		hole_viewport.render_target_update_mode = update_mode

func set_fill_color(value: Color) -> void:
	fill_color = value
	set_param("fill_color", value)

func set_outline_color(value: Color) -> void:
	outline_color = value
	set_param("outline_color", value)

func set_outline_width(value: int) -> void:
	outline_width = value
	set_param("outline_width", value)

func set_outline_outside(value: bool) -> void:
	outline_outside = value
	set_param("outline_outside", value)

func set_eye_color(value: Color) -> void:
	eye_color = value
	set_param("eye_color", value)

func set_eye_tolerance(value: float) -> void:
	eye_tolerance = value
	set_param("eye_tolerance", value)

func set_flash_min_brightness(value: float) -> void:
	flash_min_brightness = value
	set_param("flash_min_brightness", value)

func set_show_mask(value: bool) -> void:
	show_mask = value
	set_param("show_mask", value)

func set_hole_max_size(value: int) -> void:
	hole_max_size = value
	if hole_material != null:
		hole_material.set_shader_parameter("hole_max_size", value)
