extends Node2D

@export_group("Flood-fill (remplissage des trous)")
@export var flood_steps: int = 12
@export var flood_step_radius: int = 2

@export_group("Outline")
@export var outline_color: Color = Color.WHITE
@export var fill_color: Color = Color.BLACK
@export var outline_width: int = 1

@export_group("Debug")
@export var show_raw_mask: bool = false   # true = affiche le masque brut au lieu du rendu final

@onready var source_viewport: SubViewport = $SourceViewport
@onready var display: Sprite2D = $Display

const SHADER_DIR := "res://Assets/Léonce/Scripts/Outline Shader/"

func _ready() -> void:
	var flood_result: Texture2D = _build_flood_chain(source_viewport)

	if show_raw_mask:
		display.texture = flood_result
		display.material = null
		display.centered = false
	else:
		var display_mat := ShaderMaterial.new()
		display_mat.shader = load(SHADER_DIR + "outline_final.gdshader")
		display_mat.set_shader_parameter("flood_result", flood_result)
		display_mat.set_shader_parameter("original_texture", source_viewport.get_texture())
		display_mat.set_shader_parameter("outline_color", outline_color)
		display_mat.set_shader_parameter("fill_color", fill_color)
		display_mat.set_shader_parameter("outline_width", outline_width)
		display.material = display_mat
		display.texture = source_viewport.get_texture()   # peu importe, le shader lit ses propres uniforms
		display.centered = false

func _build_flood_chain(src_vp: SubViewport) -> Texture2D:
	var size: Vector2i = src_vp.size
	var src_tex: Texture2D = src_vp.get_texture()

	# --- amorçage ---
	var seed_vp := _make_pass_viewport(size, "FloodSeed")
	var seed_quad := _make_pass_sprite(seed_vp, src_tex)
	var seed_mat := ShaderMaterial.new()
	seed_mat.shader = load(SHADER_DIR + "mark_border.gdshader")
	seed_mat.set_shader_parameter("source", src_tex)
	seed_quad.material = seed_mat

	var prev_texture: Texture2D = seed_vp.get_texture()

	# --- N passes de propagation ---
	for i in flood_steps:
		var vp := _make_pass_viewport(size, "FloodStep%d" % i)
		var quad := _make_pass_sprite(vp, prev_texture)
		var mat := ShaderMaterial.new()
		mat.shader = load(SHADER_DIR + "propagate_flood.gdshader")
		mat.set_shader_parameter("previous_pass", prev_texture)
		mat.set_shader_parameter("original_texture", src_tex)
		mat.set_shader_parameter("step_radius", flood_step_radius)
		quad.material = mat

		prev_texture = vp.get_texture()

	return prev_texture

func _make_pass_viewport(size: Vector2i, node_name: String) -> SubViewport:
	var vp := SubViewport.new()
	vp.name = node_name
	vp.size = size
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(vp)
	return vp

func _make_pass_sprite(parent_vp: SubViewport, input_texture: Texture2D) -> Sprite2D:
	var quad := Sprite2D.new()
	quad.centered = false
	quad.texture = input_texture
	quad.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	quad.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	parent_vp.add_child(quad)
	return quad
