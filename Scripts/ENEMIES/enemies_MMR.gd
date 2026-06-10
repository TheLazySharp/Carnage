
## SPRITESHEET ATTENDUE :
##   - Chaque ligne = un état (walk ligne 0, attack ligne 1, etc.)
##   - Chaque colonne = une frame
##   - Taille par frame : frame_width x frame_height pixels
##
## POUR AJOUTER UN ÉTAT VISUEL :
##   1. Ajouter une nouvelle ligne à la spritesheet
##   2. Créer un EnemySpriteState (sheet_row = nouvelle ligne, frame_count = nb frames)
##   3. L'ajouter dans le dictionnaire states via _setup_default_states() ou l'inspecteur

## Structure du buffer (14 floats par instance) :
##   [0..5]  : Transform2D  (ax, ay, bx, by, ox, oy)
##   [6..9]  : Color        (r, g, b, a)
##   [10..13]: Custom data  (u_offset, v_offset, frame_w_norm, frame_h_norm)

class_name EnemiesMultiMeshRenderer
extends MultiMeshInstance2D

@export var atlas_texture : Texture2D
@export var frame_width: int = 48
@export var frame_height: int = 48
@export var max_instances: int = 1000

# --------------ANIMATION STATES -----------------------

var states: Dictionary = {} # États disponibles. Clé = nom de l'état, Valeur = ZombieSpriteState.

# Tableau des ennemis enregistrés (index = instance MultiMesh)
var registered_enemies: Array = []

# ----------- INSTANCES ---------------------
var free_indices: Array[int] = [] # Index libre pour attribution rapide
var instance_data: Dictionary = {} # Clé = instance_index, Valeur = { state, current_frame, timer, enemy_ref }


# --------- SPRITE SHEET -------------------
var sheet_cols: int = 0   # calculé depuis frame_width et texture
var sheet_rows: int = 0   # calculé depuis frame_height et texture
var frame_w_norm: float = 0.0
var frame_h_norm: float = 0.0  

# ---------------------- PERFS ----------------
var render_skip_timer : float = 0
var render_skip_steps : float = 0.016


# ---------- BUFFER --------------------
## Buffer plat envoyé au GPU en un seul appel.
## 14 floats par instance : 6 transform + 4 color + 4 custom_data
var buffer: PackedFloat32Array
const FLOATS_PER_INSTANCE: int = 16
const OFFSET_TRANSFORM: int = 0
const OFFSET_COLOR: int = 8
const OFFSET_CUSTOM: int = 12


func _ready() -> void:
	position = Vector2.ZERO
	z_index = 0
	show()
	modulate = Color.WHITE
	self_modulate = Color.WHITE
	setup_default_states()
	setup_multimesh()


func setup_default_states() -> void:
	## POUR AJOUTER UN ÉTAT : dupliquer le bloc ci-dessous avec le bon sheet_row.

	var walk_state := EnemySpriteState.new()
	walk_state.state_name = "walk"
	walk_state.sheet_row = 0
	walk_state.frame_count = 8
	walk_state.fps = 10.0
	walk_state.loop = true
	states["walk"] = walk_state



func setup_multimesh() -> void:
	if atlas_texture == null:
		push_error("EnemyMultiMeshRenderer : missing sprite_texture")
		return
	var sprite_texture : Texture2D = atlas_texture
	@warning_ignore("integer_division")
	sheet_cols = int(sprite_texture.get_width()) / frame_width
	@warning_ignore("integer_division")
	sheet_rows = int(sprite_texture.get_height()) / frame_height
	frame_w_norm = float(frame_width) / float(sprite_texture.get_width())
	frame_h_norm = float(frame_height) / float(sprite_texture.get_height())

	var quad := QuadMesh.new()
	quad.size = Vector2(frame_width, frame_height)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = quad
	mm.custom_aabb = AABB(Vector3(-1e6, -1e6, -1e6), Vector3(2e6, 2e6, 2e6))
	mm.instance_count = max_instances
	mm.visible_instance_count = -1
	multimesh = mm
	texture = sprite_texture
	show()
	texture = sprite_texture

	var mat := ShaderMaterial.new()
	mat.shader = create_sprite_sheet_shader()
	material = mat
	
	
# Initialiser le buffer plat
	buffer = PackedFloat32Array()
	buffer.resize(max_instances * FLOATS_PER_INSTANCE) 
	buffer.fill(0.0)
 


	# Initialiser chaque instance : hors écran + blanc + UV zéro
	for i in range(max_instances):
		var base := i * FLOATS_PER_INSTANCE
		# Transform : scale 0, hors écran
		buffer[base + 0] = 0.0      # ax
		buffer[base + 1] = 0.0      # ay
		buffer[base + 2] = 0.0      # bx
		buffer[base + 3] = 0.0      # by
		buffer[base + 4] = -99999.0 # ox
		buffer[base + 5] = -99999.0 # oy
		buffer[base + 6] = 0.0       # padding
		buffer[base + 7] = 0.0       # padding
		# Color : blanc opaque
		buffer[base + 8]  = 1.0
		buffer[base + 9]  = 1.0
		buffer[base + 10] = 1.0
		buffer[base + 11] = 0.0
		# Custom data : UV frame 0
		buffer[base + 12] = 0.0
		buffer[base + 13] = 0.0
		buffer[base + 14] = frame_w_norm
		buffer[base + 15] = frame_h_norm
 
	multimesh.visible_instance_count = -1

	RenderingServer.multimesh_set_buffer(multimesh.get_rid(), buffer)



	# Pré-remplir les indices libres
	free_indices.resize(max_instances)
	for i in range(max_instances):
		free_indices[i] = max_instances - 1 - i

	#for i in range(max_instances):
		#hide_instance(i)


func create_sprite_sheet_shader() -> Shader:
	## Shader qui lit les coordonnées UV depuis custom_data pour chaque instance.
	## custom_data.x = colonne de frame (normalisée 0..1)
	## custom_data.y = ligne d'état (normalisée 0..1)
	## custom_data.z = largeur d'une frame normalisée
	## custom_data.w = hauteur d'une frame normalisée

	var shader := Shader.new()
	shader.code = """

shader_type canvas_item;

varying float flash;
varying vec2 uv_scale;

void vertex() {
    vec4 cd = INSTANCE_CUSTOM;
    UV = cd.xy + UV * cd.zw;
    flash = COLOR.a;
    uv_scale = cd.zw;
}

void fragment() {
    vec4 col = texture(TEXTURE, UV);

    if (flash > 0.5) {
        vec2 texel = uv_scale / vec2(textureSize(TEXTURE, 0));
        float a_right = texture(TEXTURE, UV + vec2(texel.x, 0.0)).a;
        float a_left  = texture(TEXTURE, UV + vec2(-texel.x, 0.0)).a;
        float a_up    = texture(TEXTURE, UV + vec2(0.0, -texel.y)).a;
        float a_down  = texture(TEXTURE, UV + vec2(0.0, texel.y)).a;
        float outline = clamp(a_right + a_left + a_up + a_down, 0.0, 1.0);

        if (col.a < 0.01) {
            COLOR = vec4(1.0, 0.0, 0.0, outline);
        } else {
            COLOR = vec4(1.0, 1.0, 1.0, col.a);
        }
    } else {
        if (col.a < 0.01) discard;
        COLOR = vec4(col.rgb, col.a);
    }
}
"""
	return shader

# ─────────────────────────────────────────────
#  API PUBLIQUE — appelée par les ennemis
# ─────────────────────────────────────────────


func register_enemy(enemy: Enemy) -> int:
	if free_indices.is_empty():
		push_warning("EnemyMultiMeshRenderer : max_instances reached !")
		return -1

	var idx: int = free_indices.pop_back()
	
	var scale_modifier : Vector2 = enemy.enemy.scale_mod if enemy.enemy else Vector2.ONE
	var atlas_row : int = enemy.enemy.atlas_row if enemy.enemy else 0
	
	var base := idx * FLOATS_PER_INSTANCE + OFFSET_COLOR
	buffer[base + 0] = 1.0
	buffer[base + 1] = 1.0
	buffer[base + 2] = 1.0
	buffer[base + 3] = 0.0
	
	
	instance_data[idx] = {
		"enemy": enemy,
		"state": "walk",
		"current_frame": 0,
		"timer": 0.0,
		"flip_h": false,
		"scale": scale_modifier,
		"row": atlas_row,
		"last_pos": Vector2.INF
	}

	write_transform(idx, enemy.global_position, enemy.rotation, false,scale_modifier)
	write_uv(idx, 0, atlas_row)
	return idx


func unregister_enemy(instance_index: int) -> void:
	if instance_index < 0:
		return

	var base := instance_index * FLOATS_PER_INSTANCE
	buffer[base + 0] = 0.0
	buffer[base + 1] = 0.0
	buffer[base + 2] = 0.0
	buffer[base + 3] = 0.0
	buffer[base + 4] = -99999.0
	buffer[base + 5] = -99999.0
	instance_data.erase(instance_index)
	free_indices.push_back(instance_index)


## Change l'état d'animation d'un ennemi.
## ex: renderer.set_enemy_state(my_index, "attack")
func set_enemy_state(instance_index: int, new_state_name: String) -> void:
	if instance_index < 0:
		return
	var key := new_state_name.to_lower()
	if !states.has(key):
		push_warning("EnemyMultiMeshRenderer : unknown state : " + new_state_name)
		return
	var data: Dictionary = instance_data.get(instance_index, {})
	if data.is_empty() or data["state"] == key:
		return
	data["state"] = key
	data["current_frame"] = 0
	data["timer"] = 0.0
 

func _process(delta: float) -> void:
	if multimesh == null:
		return

	render_skip_timer += delta
	if render_skip_timer < render_skip_steps:
		return
	render_skip_timer -= render_skip_steps
	
	@warning_ignore("unused_variable")
	var is_instance_changed: bool = false
	for idx: int in instance_data:
		var data: Dictionary = instance_data[idx]
		var enemy: Enemy = data["enemy"]
		if !is_instance_valid(enemy):
			continue

		var new_flip := enemy.velocity.x < 0
		if new_flip != data["flip_h"]:
			data["flip_h"] = new_flip
		var new_scale: Vector2 = data.get("scale", Vector2.ONE)
		write_transform(idx, enemy.global_position, enemy.rotation, data["flip_h"],new_scale)
		
		# ── Animation ──
		var enemy_state: EnemySpriteState = states.get(data["state"])
		if enemy_state == null:
			continue

		data["timer"] += delta
		var frame_duration := 1.0 / enemy_state.fps
		if data["timer"] >= frame_duration:
			data["timer"] -= frame_duration
			var next_frame: int = (data["current_frame"] + 1) % enemy_state.frame_count
			if not enemy_state.loop:
				next_frame = min(data["current_frame"] + 1, enemy_state.frame_count - 1)
			if next_frame != data["current_frame"]:
				data["current_frame"] = next_frame
				write_uv(idx, next_frame, data["row"])
				is_instance_changed = true

	if not is_visible_in_tree():
		print("RENDERER INVISIBLE !")

	RenderingServer.multimesh_set_buffer(multimesh.get_rid(), buffer)

func write_transform(idx: int, pos: Vector2, rot: float, flip_h: bool, new_scale : Vector2 = Vector2.ONE) -> void:
	var cos_r := cos(rot)
	var sin_r := sin(rot)
	var base := idx * FLOATS_PER_INSTANCE + OFFSET_TRANSFORM
	buffer[base + 0] = (-cos_r if flip_h else cos_r) * new_scale.x  # x.x
	buffer[base + 1] = (-sin_r if flip_h else sin_r) * new_scale.x  # y.x
	buffer[base + 2] = 0.0                           # padding
	buffer[base + 3] = pos.x                         # origin.x
	buffer[base + 4] = sin_r if flip_h else -sin_r  # x.y  (signe inversé pour flip)
	buffer[base + 5] = cos_r * new_scale.y              # y.y
	buffer[base + 6] = 0.0                           # padding
	buffer[base + 7] = pos.y                         # origin.y

 
func write_uv(idx: int, frame_col: int, frame_row: int) -> void:
	var base := idx * FLOATS_PER_INSTANCE + OFFSET_CUSTOM
	buffer[base + 0] = frame_col * frame_w_norm  # u_offset
	buffer[base + 1] = frame_row * frame_h_norm  # v_offset
	buffer[base + 2] = frame_w_norm
	buffer[base + 3] = frame_h_norm


func set_enemy_color(instance_index: int, color: Color) -> void:
	if instance_index < 0:
		return
	var base := instance_index * FLOATS_PER_INSTANCE + OFFSET_COLOR

	buffer[base + 0] = color.r
	buffer[base + 1] = color.g
	buffer[base + 2] = color.b
	buffer[base + 3] = color.a


func multimesh_set_color_by_index(idx: int, color: Color) -> void:
	set_enemy_color(idx, color)
	
func set_enemy_flash(instance_index: int, flashing: bool) -> void:
	if instance_index < 0:
		return
	var base := instance_index * FLOATS_PER_INSTANCE + OFFSET_COLOR
	buffer[base + 3] = 1.0 if flashing else 0.0
	(material as ShaderMaterial).set_shader_parameter("flash_test", 1.0 if flashing else 0.0)


func set_buffer_alpha(idx: int, value: float) -> void:
	var base := idx * FLOATS_PER_INSTANCE + OFFSET_COLOR
	if idx == 39 and buffer[base + 3] != value:
		print("alpha idx39 changé à ", value, " depuis:")
		print(get_stack())
		buffer[base + 3] = value


func set_enemy_scale(instance_index: int, new_scale: Vector2) -> void:
	if instance_index < 0:
		return
	if instance_data.has(instance_index):
		instance_data[instance_index]["scale"] = new_scale
