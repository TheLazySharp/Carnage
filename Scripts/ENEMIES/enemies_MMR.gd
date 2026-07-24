## SPRITESHEET ATTENDUE :
##   - Chaque ligne = un état (walk ligne 0, attack ligne 1, etc.)
##   - Chaque colonne = une frame
##   - Taille par frame : frame_width x frame_height pixels
##
## POUR AJOUTER UN ÉTAT VISUEL :
##   1. Ajouter une nouvelle ligne à la spritesheet
##   2. Créer un EnemySpriteState (sheet_row = nouvelle ligne, frame_count = nb frames)
##   3. L'ajouter dans le dictionnaire states via _setup_default_states() ou l'inspecteur


class_name EnemiesMultiMeshRenderer
extends MultiMeshInstance2D

@export var atlas_texture : Texture2D
@export var frame_width: int = 48
@export var frame_height: int = 48
@export var max_instances: int = 1000

# --------- ORIENTATION 360 -------------------
## Cible vers laquelle les ennemis s'orientent (la voiture).
@onready var car: Node2D = get_node_or_null("/root/World/Car")
## Décalage d'angle en degrés si le sprite de base ne "regarde" pas vers la droite (+X).
## Ex : sprite dessiné regardant vers le haut -> mettre 90 ; vers le bas -> -90.
@export var sprite_angle_offset: float = 0.0

# --------------ANIMATION STATES -----------------------

var states: Dictionary = {} # États disponibles. Clé = nom de l'état, Valeur = ZombieSpriteState.

# Tableau des ennemis enregistrés (index = instance MultiMesh)
#var registered_enemies: Array = []

# ----------- INSTANCES ---------------------
var free_indices: Array[int] = [] # Index libre pour attribution rapide
#var instance_data: Dictionary = {} # Clé = instance_index, Valeur = { state, current_frame, timer, enemy_ref }

var active_indices: Array[int] = []   # remplace l'itération sur instance_data
var inst_enemy: Array = []            # Enemy ou null
var inst_state: Array = []            # EnemySpriteState
var inst_frame: PackedInt32Array
var inst_timer: PackedFloat32Array
var inst_flip: PackedByteArray
var inst_rot: PackedFloat32Array     # rotation courante (radians) vers la voiture
var inst_row: PackedInt32Array
var inst_scale: Array = []            # Vector2
var inst_last_pos: Array = []

# --------- SPRITE SHEET -------------------
var sheet_cols: int = 0   # calculé depuis frame_width et texture
var sheet_rows: int = 0   # calculé depuis frame_height et texture
var frame_w_norm: float = 0.0
var frame_h_norm: float = 0.0

# ---------------------- PERFS ----------------
var render_skip_timer : float = 0
var render_skip_steps : float = 0.033
var buffer_is_dirty : bool = false


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

	var walk_state: EnemySpriteState = EnemySpriteState.new()
	walk_state.state_name = "walk"
	walk_state.sheet_row = 0
	walk_state.frame_count = 8
	walk_state.fps = 10.0
	walk_state.loop = true
	states["walk"] = walk_state



func setup_multimesh() -> void:
	inst_enemy.resize(max_instances)
	inst_state.resize(max_instances)
	inst_frame.resize(max_instances)
	inst_timer.resize(max_instances)
	inst_flip.resize(max_instances)
	inst_rot.resize(max_instances)
	inst_row.resize(max_instances)
	inst_scale.resize(max_instances)
	inst_last_pos.resize(max_instances)
	inst_scale.fill(Vector2.ONE)


	if atlas_texture == null:
		push_error("EnemyMultiMeshRenderer : missing sprite_texture")
		return
	var sprite_texture: Texture2D = atlas_texture
	@warning_ignore("integer_division")
	sheet_cols = int(sprite_texture.get_width()) / frame_width
	@warning_ignore("integer_division")
	sheet_rows = int(sprite_texture.get_height()) / frame_height
	frame_w_norm = float(frame_width) / float(sprite_texture.get_width())
	frame_h_norm = float(frame_height) / float(sprite_texture.get_height())

	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(frame_width, frame_height)

	var mm: MultiMesh = MultiMesh.new()
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

	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = create_sprite_sheet_shader()
	material = mat


# Initialiser le buffer plat
	buffer = PackedFloat32Array()
	buffer.resize(max_instances * FLOATS_PER_INSTANCE)
	buffer.fill(0.0)



	# Initialiser chaque instance : hors écran + blanc + UV zéro
	for i: int in range(max_instances):
		var base: int = i * FLOATS_PER_INSTANCE
		buffer[base + 0] = 0.0   # x.x
		buffer[base + 1] = 0.0   # y.x
		buffer[base + 2] = 0.0   # padding
		buffer[base + 3] = 0.0   # origin.x
		buffer[base + 4] = 0.0   # x.y
		buffer[base + 5] = 0.0   # y.y
		buffer[base + 6] = 0.0   # padding
		buffer[base + 7] = 0.0   # origin.y

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
	for i: int in range(max_instances):
		free_indices[i] = max_instances - 1 - i

func create_sprite_sheet_shader() -> Shader:
	## Shader qui lit les coordonnées UV depuis custom_data pour chaque instance.
	## custom_data.x = colonne de frame (normalisée 0..1)
	## custom_data.y = ligne d'état (normalisée 0..1)
	## custom_data.z = largeur d'une frame normalisée
	## custom_data.w = hauteur d'une frame normalisée

	var shader: Shader = Shader.new()
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
	active_indices.append(idx)
	var scale_modifier: Vector2 = enemy.enemy.scale_mod if enemy.enemy else Vector2.ONE
	var atlas_row: int = enemy.enemy.atlas_row if enemy.enemy else 0

	var base: int = idx * FLOATS_PER_INSTANCE + OFFSET_COLOR
	buffer[base + 0] = 1.0
	buffer[base + 1] = 1.0
	buffer[base + 2] = 1.0
	buffer[base + 3] = 0.0

	var init_rot: float = angle_to_car(enemy.global_position)

	inst_enemy[idx] = enemy
	inst_state[idx] = states["walk"]
	inst_frame[idx] = 0
	inst_timer[idx] = 0.0
	inst_flip[idx] = 0
	inst_rot[idx] = init_rot
	inst_row[idx] = atlas_row
	inst_scale[idx] = scale_modifier
	inst_last_pos[idx] = Vector2.INF


	write_transform(idx, enemy.global_position, init_rot, false, scale_modifier)
	write_uv(idx, 0, atlas_row)
	return idx


func unregister_enemy(instance_index: int) -> void:
	if instance_index < 0:
		return

	var base: int = instance_index * FLOATS_PER_INSTANCE
	buffer[base + 0] = 0.0
	buffer[base + 1] = 0.0
	buffer[base + 4] = 0.0
	buffer[base + 5] = 0.0
	buffer[base + 7] = 0.0
	buffer_is_dirty = true

	inst_enemy[instance_index] = null
	active_indices.erase(instance_index)
	free_indices.push_back(instance_index)


func set_enemy_state(instance_index: int, new_state_name: String) -> void:
	if instance_index < 0 or inst_enemy[instance_index] == null:
		return
	var key: String = new_state_name.to_lower()
	if !states.has(key):
		push_warning("EnemyMultiMeshRenderer : unknown state : " + new_state_name)
		return
	if inst_state[instance_index].state_name == key:
		return
	inst_state[instance_index] = states[key]
	inst_frame[instance_index] = 0
	inst_timer[instance_index] = 0.0


## Angle (radians) pointant depuis pos vers la voiture, + décalage sprite.
func angle_to_car(pos: Vector2) -> float:
	if car == null:
		return 0.0
	return (car.global_position - pos).angle() + deg_to_rad(sprite_angle_offset)


func _process(delta: float) -> void:
	if multimesh == null:
		return

	render_skip_timer += delta
	if render_skip_timer < render_skip_steps:
		return
	var step: float = render_skip_timer   # delta accumulé : l'animation garde sa vitesse réelle
	render_skip_timer = 0.0

	for k: int in range(active_indices.size() - 1, -1, -1):
		var idx: int = active_indices[k]
		var enemy: Enemy = inst_enemy[idx]
		if !is_instance_valid(enemy):
			continue

		# ── Transform : orientation selon l'état ──
		# Chase / Attack -> face à la voiture (360). Sinon (idle) -> direction du déplacement.
		var pos: Vector2 = enemy.global_position
		var rot: float = inst_rot[idx]   # conserve l'angle courant par défaut (ex : idle immobile)
		var sname: String = ""
		var sm:= enemy.state_machine
		if sm != null and sm.current_state != null:
			sname = String(sm.current_state.name).to_lower()
		if sname == "chase" or sname == "attack":
			rot = angle_to_car(pos)
		elif enemy.velocity.length_squared() > 0.01:
			rot = enemy.velocity.angle() + deg_to_rad(sprite_angle_offset)
		if pos != inst_last_pos[idx] or rot != inst_rot[idx]:
			inst_last_pos[idx] = pos
			inst_rot[idx] = rot
			write_transform(idx, pos, rot, false, inst_scale[idx])

		# ── Animation ──
		var st: EnemySpriteState = inst_state[idx]
		if st == null:
			continue
		inst_timer[idx] += step
		var frame_duration: float = 1.0 / st.fps
		if inst_timer[idx] >= frame_duration:
			inst_timer[idx] -= frame_duration
			var next_frame: int = (inst_frame[idx] + 1) % st.frame_count
			if not st.loop:
				next_frame = mini(inst_frame[idx] + 1, st.frame_count - 1)
			if next_frame != inst_frame[idx]:
				inst_frame[idx] = next_frame
				write_uv(idx, next_frame, inst_row[idx])

	if buffer_is_dirty:
		RenderingServer.multimesh_set_buffer(multimesh.get_rid(), buffer)
		buffer_is_dirty = false


func write_transform(idx: int, pos: Vector2, rot: float, flip_h: bool, new_scale: Vector2 = Vector2.ONE) -> void:
	# Matrice de rotation 2D propre (Transform2D) + échelle + flip horizontal éventuel.
	var sx: float = -new_scale.x if flip_h else new_scale.x
	var sy: float = new_scale.y
	var xf: Transform2D = Transform2D(rot, pos)
	xf.x *= sx   # axe X mis à l'échelle (et inversé si flip)
	xf.y *= sy   # axe Y mis à l'échelle
	var base: int = idx * FLOATS_PER_INSTANCE + OFFSET_TRANSFORM
	buffer[base + 0] = xf.x.x     # x.x
	buffer[base + 1] = xf.y.x     # y.x
	buffer[base + 2] = 0.0        # padding
	buffer[base + 3] = xf.origin.x
	buffer[base + 4] = xf.x.y     # x.y
	buffer[base + 5] = xf.y.y     # y.y
	buffer[base + 6] = 0.0        # padding
	buffer[base + 7] = xf.origin.y
	buffer_is_dirty = true

func write_uv(idx: int, frame_col: int, frame_row: int) -> void:
	var base: int = idx * FLOATS_PER_INSTANCE + OFFSET_CUSTOM
	buffer[base + 0] = frame_col * frame_w_norm  # u_offset
	buffer[base + 1] = frame_row * frame_h_norm  # v_offset
	buffer[base + 2] = frame_w_norm
	buffer[base + 3] = frame_h_norm

	buffer_is_dirty = true


func set_enemy_color(instance_index: int, color: Color) -> void:
	if instance_index < 0:
		return
	var base: int = instance_index * FLOATS_PER_INSTANCE + OFFSET_COLOR

	buffer[base + 0] = color.r
	buffer[base + 1] = color.g
	buffer[base + 2] = color.b
	buffer[base + 3] = color.a

	buffer_is_dirty = true



func multimesh_set_color_by_index(idx: int, color: Color) -> void:
	set_enemy_color(idx, color)

func set_enemy_flash(instance_index: int, flashing: bool) -> void:
	if instance_index < 0:
		return
	var base: int = instance_index * FLOATS_PER_INSTANCE + OFFSET_COLOR
	buffer[base + 3] = 1.0 if flashing else 0.0

	buffer_is_dirty = true

func set_enemy_scale(instance_index: int, new_scale: Vector2) -> void:
	if instance_index < 0:
		return
	inst_scale[instance_index] = new_scale
	inst_last_pos[instance_index] = Vector2.INF
