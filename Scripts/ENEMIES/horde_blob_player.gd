class_name HordeBlobLayer
extends Node2D

## Renders dense packs of enemies as one black mass with a single outline.
## Membership is decided on a coarse world-space grid recentered on the camera:
## an enemy belongs to the mass when at least min_cluster_count enemies (itself included)
## stand in the 3x3 cells around it. Members are hidden by their EnemyTypePool and
## splatted into a low-res density texture, drawn as one quad with a threshold shader.

# ---------------- CLUSTERING ----------------
@export var enabled: bool = true
## Enemies (itself included) needed in the 3x3 neighborhood to join the mass.
@export var min_cluster_count: int = 5
## A member stays while its neighborhood count >= min_cluster_count - hysteresis (anti flicker).
@export var hysteresis: int = 1
## Cell size = largest registered sprite size * this ratio.
@export var cell_size_ratio: float = 0.65
## Extra cells around the visible area.
@export var margin_cells: int = 2
## An enemy knocked back faster than this (px/s) leaves the mass -> it bursts out of the black.
@export var knockback_exclusion_speed: float = 120.0
## Enemies closer than this to the car never join the mass (0 = disabled). Keeps contact readable.
@export var car_exclusion_radius: float = 0.0
## Radius (px) around a car impact where the mass breaks apart (members and non-members alike).
@export var break_radius: float = 110.0
## How long (s) a broken area stays open before enemies can regroup.
@export var break_duration: float = 0.8

# ---------------- LOOK ----------------
@export_group("Look")
## Optional .gdshader override (same code as create_blob_shader). Built-in shader otherwise.
@export var blob_shader: Shader = null
## Optional seamless noise. Generated otherwise.
@export var noise_texture: Texture2D = null
@export var fill_color: Color = Color(0.02, 0.0, 0.02, 1.0): set = set_fill_color
@export var outline_color: Color = Color(1.0, 1.0, 1.0, 1.0): set = set_outline_color
## Outline thickness in world pixels.
@export_range(0.0, 16.0, 0.5) var outline_width_px: float = 3.0: set = set_outline_width_px
## Density needed to be inside the mass. Lower = fatter mass.
@export_range(0.05, 0.95, 0.01) var fill_threshold: float = 0.5: set = set_fill_threshold
## 0 = hard pixel edges, 1 = anti-aliased edges.
@export_range(0.0, 2.0, 0.1) var edge_softness: float = 1.0: set = set_edge_softness
## Density written in the 4 orthogonal / 4 diagonal cells around a member (0-255). Lower = tighter mass.
@export_range(0, 255) var splat_orthogonal: int = 110
@export_range(0, 255) var splat_diagonal: int = 90

@export_group("Wobble")
## Ripple amplitude in world pixels.
@export_range(0.0, 32.0, 0.5) var wobble_amount_px: float = 6.0: set = set_wobble_amount_px
@export_range(0.0, 2.0, 0.01) var wobble_speed: float = 0.15: set = set_wobble_speed
## World pixels -> noise UV. Smaller = wider, slower waves.
@export_range(0.001, 0.05, 0.001) var wobble_scale: float = 0.005: set = set_wobble_scale
## Breathing of the mass edge (density units, 0 = off).
@export_range(0.0, 0.3, 0.01) var pulse_amount: float = 0.04: set = set_pulse_amount
@export_range(0.0, 10.0, 0.1) var pulse_speed: float = 2.0: set = set_pulse_speed

# ---------------- INTERNALS ----------------

var cell_size: float = 32.0
var inverse_cell_size: float = 1.0 / 32.0
var reference_sprite_size: float = 0.0
var grid_dirty: bool = true

var grid_width: int = 0
var grid_height: int = 0
var grid_origin: Vector2 = Vector2.ZERO
var counts: PackedInt32Array = PackedInt32Array()
var density: PackedByteArray = PackedByteArray()
var density_image: Image = null
var density_texture: ImageTexture = null

var shader_material: ShaderMaterial = null
var camera: Camera2D = null
var car_position: Vector2 = Vector2(1e9, 1e9)
var knockback_exclusion_speed_squared: float = 0.0
var car_exclusion_radius_squared: float = 0.0

var members_this_step: int = 0
const MAX_BREAK_POINTS: int = 16
var break_points: Array[Vector3] = []   # x, y, expiry time (seconds)
var break_write_cursor: int = 0
var has_break_points: bool = false
var break_radius_squared: float = 0.0
var break_merge_radius_squared: float = 0.0

func _ready() -> void:
	position = Vector2.ZERO
	z_index = 0
	# Linear filtering is what merges the cells into one smooth mass. Do not rely on the project default.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	knockback_exclusion_speed_squared = knockback_exclusion_speed * knockback_exclusion_speed
	car_exclusion_radius_squared = car_exclusion_radius * car_exclusion_radius
	break_radius_squared = break_radius * break_radius
	break_merge_radius_squared = break_radius * 0.5 * break_radius * 0.5
	
	if noise_texture == null:
		noise_texture = create_noise_texture()
	shader_material = ShaderMaterial.new()
	shader_material.shader = blob_shader if blob_shader != null else create_blob_shader()
	material = shader_material
	apply_shader_parameters()


func _draw() -> void:
	if density_texture == null:
		return
	draw_texture_rect(density_texture, Rect2(Vector2.ZERO, Vector2(grid_width, grid_height) * cell_size), false)


# ─────────────────────────────────────────────
#  Public API — called by EnemiesMultiMeshRenderer / EnemyTypePool
# ─────────────────────────────────────────────

## Called by each pool at creation. The grid resolution follows the largest sprite.
func register_sprite_size(sprite_size: Vector2) -> void:
	var largest: float = maxf(sprite_size.x, sprite_size.y)
	if largest <= reference_sprite_size:
		return
	reference_sprite_size = largest
	cell_size = maxf(8.0, roundf(largest * cell_size_ratio))
	inverse_cell_size = 1.0 / cell_size
	set_param("cell_size", cell_size)
	grid_dirty = true


## Recenter the grid on the camera and clear it. Returns false if nothing can be done this step.
func begin_step(current_car_position: Vector2) -> bool:
	if camera == null:
		camera = get_viewport().get_camera_2d()
		if camera == null:
			return false
	car_position = current_car_position

	var view_size: Vector2 = get_viewport_rect().size / camera.zoom
	var needed_width: int = int(ceil(view_size.x * inverse_cell_size)) + margin_cells * 2
	var needed_height: int = int(ceil(view_size.y * inverse_cell_size)) + margin_cells * 2
	if grid_dirty or needed_width != grid_width or needed_height != grid_height:
		rebuild_grid(needed_width, needed_height)

	var camera_center: Vector2 = camera.get_screen_center_position()
	grid_origin = (camera_center * inverse_cell_size - Vector2(grid_width, grid_height) * 0.5).floor() * cell_size
	position = grid_origin

	# Expire old break points
	var now: float = Time.get_ticks_msec() * 0.001
	for i: int in range(break_points.size() - 1, -1, -1):
		if break_points[i].z <= now:
			break_points.remove_at(i)
	has_break_points = !break_points.is_empty()

	members_this_step = 0
	counts.fill(0)
	density.fill(0)
	return true


## Pass 1: every candidate enemy adds itself to its cell.
func add_count(world_position: Vector2) -> void:
	var cell_x: int = int((world_position.x - grid_origin.x) * inverse_cell_size)
	var cell_y: int = int((world_position.y - grid_origin.y) * inverse_cell_size)
	if cell_x < 1 or cell_y < 1 or cell_x >= grid_width - 1 or cell_y >= grid_height - 1:
		return
	if is_excluded(world_position):
		return
	counts[cell_y * grid_width + cell_x] += 1


## Pass 2: true if the enemy belongs to a mass. Splats its density when it does.
func resolve(world_position: Vector2, was_member: bool) -> bool:
	var cell_x: int = int((world_position.x - grid_origin.x) * inverse_cell_size)
	var cell_y: int = int((world_position.y - grid_origin.y) * inverse_cell_size)
	if cell_x < 1 or cell_y < 1 or cell_x >= grid_width - 1 or cell_y >= grid_height - 1:
		return false
	if is_excluded(world_position):
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
	if neighborhood_count < required:
		return false

	# 3x3 splat, saturating
	density[index] = 255
	density[up] = mini(255, density[up] + splat_orthogonal)
	density[down] = mini(255, density[down] + splat_orthogonal)
	density[index - 1] = mini(255, density[index - 1] + splat_orthogonal)
	density[index + 1] = mini(255, density[index + 1] + splat_orthogonal)
	density[up - 1] = mini(255, density[up - 1] + splat_diagonal)
	density[up + 1] = mini(255, density[up + 1] + splat_diagonal)
	density[down - 1] = mini(255, density[down - 1] + splat_diagonal)
	density[down + 1] = mini(255, density[down + 1] + splat_diagonal)
	members_this_step += 1
	return true

## Car exclusion radius + active break points.
func is_excluded(world_position: Vector2) -> bool:
	if car_exclusion_radius_squared > 0.0 and world_position.distance_squared_to(car_position) < car_exclusion_radius_squared:
		return true
	if has_break_points:
		for point: Vector3 in break_points:
			var dx: float = world_position.x - point.x
			var dy: float = world_position.y - point.y
			if dx * dx + dy * dy < break_radius_squared:
				return true
	return false


## Called on a strong impact: opens a hole in the mass around this position.
func add_break_point(world_position: Vector2) -> void:
	var expiry: float = Time.get_ticks_msec() * 0.001 + break_duration
	# A fresh point already covers this spot: refresh it instead of stacking points
	for i: int in range(break_points.size()):
		var point: Vector3 = break_points[i]
		var dx: float = world_position.x - point.x
		var dy: float = world_position.y - point.y
		if dx * dx + dy * dy < break_merge_radius_squared:
			break_points[i] = Vector3(point.x, point.y, expiry)
			return
	var new_point: Vector3 = Vector3(world_position.x, world_position.y, expiry)
	if break_points.size() < MAX_BREAK_POINTS:
		break_points.append(new_point)
	else:
		break_points[break_write_cursor] = new_point
		break_write_cursor = (break_write_cursor + 1) % MAX_BREAK_POINTS
	has_break_points = true

## Upload the density grid to the GPU (same size/format -> in-place update).
func end_step() -> void:
	density_image.set_data(grid_width, grid_height, false, Image.FORMAT_R8, density)
	density_texture.update(density_image)


# ─────────────────────────────────────────────
#  INTERNALS
# ─────────────────────────────────────────────

func rebuild_grid(new_width: int, new_height: int) -> void:
	grid_width = new_width
	grid_height = new_height
	grid_dirty = false
	counts.resize(grid_width * grid_height)
	density.resize(grid_width * grid_height)
	counts.fill(0)
	density.fill(0)
	density_image = Image.create_from_data(grid_width, grid_height, false, Image.FORMAT_R8, density)
	if density_texture == null:
		density_texture = ImageTexture.create_from_image(density_image)
	else:
		density_texture.set_image(density_image)
	queue_redraw()


func create_noise_texture() -> Texture2D:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.015
	noise.fractal_octaves = 2
	var generated: NoiseTexture2D = NoiseTexture2D.new()
	generated.width = 256
	generated.height = 256
	generated.seamless = true
	generated.noise = noise
	return generated


func apply_shader_parameters() -> void:
	set_param("noise_texture", noise_texture)
	set_param("fill_color", fill_color)
	set_param("outline_color", outline_color)
	set_param("outline_width_px", outline_width_px)
	set_param("fill_threshold", fill_threshold)
	set_param("edge_softness", edge_softness)
	set_param("wobble_amount_px", wobble_amount_px)
	set_param("wobble_speed", wobble_speed)
	set_param("wobble_scale", wobble_scale)
	set_param("pulse_amount", pulse_amount)
	set_param("pulse_speed", pulse_speed)
	set_param("cell_size", cell_size)


func set_param(param_name: String, value: Variant) -> void:
	# Setters run before _ready when the scene loads: material may not exist yet.
	if shader_material != null:
		shader_material.set_shader_parameter(param_name, value)


# Setters keep the shader in sync when values change in the inspector at runtime.
func set_fill_color(value: Color) -> void:
	fill_color = value
	set_param("fill_color", value)

func set_outline_color(value: Color) -> void:
	outline_color = value
	set_param("outline_color", value)

func set_outline_width_px(value: float) -> void:
	outline_width_px = value
	set_param("outline_width_px", value)

func set_fill_threshold(value: float) -> void:
	fill_threshold = value
	set_param("fill_threshold", value)

func set_edge_softness(value: float) -> void:
	edge_softness = value
	set_param("edge_softness", value)

func set_wobble_amount_px(value: float) -> void:
	wobble_amount_px = value
	set_param("wobble_amount_px", value)

func set_wobble_speed(value: float) -> void:
	wobble_speed = value
	set_param("wobble_speed", value)

func set_wobble_scale(value: float) -> void:
	wobble_scale = value
	set_param("wobble_scale", value)

func set_pulse_amount(value: float) -> void:
	pulse_amount = value
	set_param("pulse_amount", value)

func set_pulse_speed(value: float) -> void:
	pulse_speed = value
	set_param("pulse_speed", value)


func create_blob_shader() -> Shader:
	## TEXTURE = the density grid (R8, one texel per cell), sampled with linear filtering.
	## Fill = density above threshold. Outline = dilation of the fill by outline_width_px (8 taps).
	## Wobble = domain warp of the sampling UV by world-space noise, so fill and outline ripple together.
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform sampler2D noise_texture : repeat_enable, filter_linear;
uniform vec4 fill_color : source_color = vec4(0.02, 0.0, 0.02, 1.0);
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width_px = 3.0;
uniform float fill_threshold = 0.5;
uniform float edge_softness = 1.0;
uniform float wobble_amount_px = 6.0;
uniform float wobble_speed = 0.15;
uniform float wobble_scale = 0.005;
uniform float pulse_amount = 0.04;
uniform float pulse_speed = 2.0;
uniform float cell_size = 32.0;

varying vec2 world_position;

// Bilinear with smoothstepped weights: removes the diamond facets of plain bilinear on a tiny texture.
vec2 smooth_uv(vec2 uv, vec2 texel_size) {
    vec2 grid_size = 1.0 / texel_size;
    vec2 p = uv * grid_size - 0.5;
    vec2 i = floor(p);
    vec2 f = p - i;
    f = f * f * (3.0 - 2.0 * f);
    return (i + f + 0.5) * texel_size;
}

float sample_density(sampler2D density_tex, vec2 uv, vec2 texel_size) {
    return texture(density_tex, smooth_uv(uv, texel_size)).r;
}

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
    vec2 texel_size = TEXTURE_PIXEL_SIZE;
    vec2 px_to_uv = texel_size / cell_size; // one world pixel expressed in density UV

    // Domain warp in world space (does not slide with the camera)
    vec2 noise_uv = world_position * wobble_scale + TIME * wobble_speed * vec2(1.0, 0.7);
    vec2 warp = vec2(
        texture(noise_texture, noise_uv).r,
        texture(noise_texture, noise_uv + vec2(0.37, 0.61)).r
    ) - 0.5;
    vec2 uv = UV + warp * 2.0 * wobble_amount_px * px_to_uv;

    float threshold = fill_threshold + sin(TIME * pulse_speed) * pulse_amount;
    float density = sample_density(TEXTURE, uv, texel_size);

    // Outline: dilate the fill by outline_width_px, constant thickness in world pixels
    float dilated = density;
    vec2 ring_radius = outline_width_px * px_to_uv;
    for (int i = 0; i < 8; i++) {
        float angle = float(i) * TAU / 8.0;
        vec2 offset = vec2(cos(angle), sin(angle)) * ring_radius;
        dilated = max(dilated, sample_density(TEXTURE, uv + offset, texel_size));
    }

    // smoothstep(a, a, x) is undefined in GLSL -> keep a minimal width
    float fill_aa = max(fwidth(density) * edge_softness, 1e-4);
    float ring_aa = max(fwidth(dilated) * edge_softness, 1e-4);
    float fill = smoothstep(threshold - fill_aa, threshold + fill_aa, density);
    float shape = smoothstep(threshold - ring_aa, threshold + ring_aa, dilated);

    vec4 color = mix(outline_color, fill_color, fill);
    color.a *= shape;
    COLOR = color;
}
"""
	return shader
