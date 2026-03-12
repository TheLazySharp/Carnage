
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


@export var sprite_texture: Texture2D
@export var frame_width: int = 90
@export var frame_height: int = 90
@export var max_instances: int = 1000

# --------------ANIMATION STATES -----------------------

## États disponibles. Clé = nom de l'état, Valeur = ZombieSpriteState.
## Rempli automatiquement par _setup_default_states().

var states: Dictionary = {}

# Tableau des ennemis enregistrés (index = instance MultiMesh)
var registered_enemies: Array = []

# Index libre pour attribution rapide
var free_indices: Array[int] = []

# Données d'animation par instance
# Clé = instance_index, Valeur = { state, current_frame, timer, enemy_ref }
var instance_data: Dictionary = {}

# Dimensions de la spritesheet en nombre de frames
var sheet_cols: int = 0   # calculé depuis frame_width et texture
var sheet_rows: int = 0   # calculé depuis frame_height et texture


func _ready() -> void:
	setup_default_states()
	setup_multimesh()


func setup_default_states() -> void:
	## POUR AJOUTER UN ÉTAT : dupliquer le bloc ci-dessous avec le bon sheet_row.

	var walk_state := EnemySpriteState.new()
	walk_state.state_name = "walk"
	walk_state.sheet_row = 0
	walk_state.frame_count = 10
	walk_state.fps = 10.0
	walk_state.loop = true
	states["walk"] = walk_state



func setup_multimesh() -> void:	
	if sprite_texture == null:
		push_error("EnemyMultiMeshRenderer : missing sprite_texture")
		return

	@warning_ignore("integer_division")
	sheet_cols = int(sprite_texture.get_width()) / frame_width
	@warning_ignore("integer_division")
	sheet_rows = int(sprite_texture.get_height()) / frame_height

	# Créer le QuadMesh aux bonnes dimensions
	var quad := QuadMesh.new()
	quad.size = Vector2(frame_width, frame_height)
	
	# Créer et configurer le MultiMesh
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.instance_count = max_instances
	mm.mesh = quad

	multimesh = mm
	texture = sprite_texture

	for i in range(max_instances):
		mm.set_instance_color(i, Color.WHITE)

	# Créer le matériau avec shader UV
	var mat := ShaderMaterial.new()
	mat.shader = create_sprite_sheet_shader()
	material = mat

	# Pré-remplir les indices libres
	free_indices.resize(max_instances)
	for i in range(max_instances):
		free_indices[i] = max_instances - 1 - i

	for i in range(max_instances):
		hide_instance(i)


func create_sprite_sheet_shader() -> Shader:
	## Shader qui lit les coordonnées UV depuis custom_data pour chaque instance.
	## custom_data.x = colonne de frame (normalisée 0..1)
	## custom_data.y = ligne d'état (normalisée 0..1)
	## custom_data.z = largeur d'une frame normalisée
	## custom_data.w = hauteur d'une frame normalisée

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

void vertex() {
	// UV de base du quad (0..1 sur x et y)
	// On les remappe vers la bonne frame dans la sheet
	
	// custom_data passé par instance :
	// .x = offset U (coin gauche de la frame)
	// .y = offset V (coin haut de la frame)  
	// .z = largeur normalisée d'une frame
	// .w = hauteur normalisée d'une frame
	
	vec4 cd = INSTANCE_CUSTOM;
	UV = vec2(
		cd.x + UV.x * cd.z,
		cd.y + UV.y * cd.w
	);
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	// Discard pixels transparents (contour du sprite)
	if (col.a < 0.01) discard;
	COLOR = vec4(col.rgb * COLOR.rgb, col.a);
}
"""
	return shader

# ─────────────────────────────────────────────
#  API PUBLIQUE — appelée par les ennemis
# ─────────────────────────────────────────────

## Enregistre un ennemi dans le renderer. Retourne son instance_index.
## À appeler dans Enemy._ready()
func register_enemy(enemy: Enemy) -> int:
	if free_indices.is_empty():
		push_warning("EnemyMultiMeshRenderer : max_instances reached !")
		return -1

	var idx: int = free_indices.pop_back()
	
	instance_data[idx] = {
		"enemy": enemy,
		"state": "walk",
		"current_frame": 0,
		"timer": 0.0,
		"flip_h": false
	}

	update_instance_transform(idx, enemy.global_position, enemy.rotation)
	update_instance_uv(idx)
	return idx


## Libère un ennemi du renderer (à appeler dans on_death, avant queue_free)
func unregister_enemy(instance_index: int) -> void:
	if instance_index < 0:
		return
	hide_instance(instance_index)
	instance_data.erase(instance_index)
	free_indices.push_back(instance_index)


## Change l'état d'animation d'un ennemi.
## ex: renderer.set_enemy_state(my_index, "attack")
func set_enemy_state(instance_index: int, new_state_name: String) -> void:
	if instance_index < 0:
		return
	if not states.has(new_state_name.to_lower()):
		push_warning("EnemyMultiMeshRenderer : unknown state : " + new_state_name)
		return
	var data: Dictionary = instance_data.get(instance_index, {})
	if data.is_empty():
		return
	if data["state"] == new_state_name.to_lower():
		return
	data["state"] = new_state_name.to_lower()
	data["current_frame"] = 0
	data["timer"] = 0.0


func _process(delta: float) -> void:
	if multimesh == null:
		return
	
	for idx : int in instance_data:
		var data: Dictionary = instance_data[idx]
		var enemy: Enemy = data["enemy"]

		if !is_instance_valid(enemy):
			continue

		# --- position update ---
		if !data.has("last_pos"):
			data["last_pos"] = Vector2.INF
		var new_pos : Vector2 = enemy.global_position
		if new_pos != data["last_pos"]:
			data["last_pos"] = new_pos
			update_instance_transform(idx, new_pos, enemy.rotation)

		# --- Flip horizontal selon la direction ------------------------------------------------------------
		var flip := enemy.velocity.x < 0
		if flip != data["flip_h"]:
			data["flip_h"] = flip
			# Le flip est géré via scale.x dans la transform

		# --- SPRITE ANIMATION PROCESS
		var enemy_state: EnemySpriteState = states.get(data["state"])
		if enemy_state == null:
			continue

		data["timer"] += delta
		var frame_duration: float = 1.0 / enemy_state.fps

		if data["timer"] >= frame_duration:
			data["timer"] -= frame_duration
			var next_frame: int = data["current_frame"] + 1

			if next_frame >= enemy_state.frame_count:
				if enemy_state.loop:
					next_frame = 0
				else:
					next_frame = enemy_state.frame_count - 1

			if next_frame != data["current_frame"]:
				data["current_frame"] = next_frame
				update_instance_uv(idx)


func update_instance_transform(idx: int, pos: Vector2, rot: float) -> void:
	var t := Transform2D()
	t = t.rotated(rot)
	t.origin = pos

	# Flip horizontal si nécessaire
	var data: Dictionary = instance_data.get(idx, {})
	if not data.is_empty() and data.get("flip_h", false):
		t.x = -t.x

	multimesh.set_instance_transform_2d(idx, t)


func update_instance_uv(idx: int) -> void:
	var data: Dictionary = instance_data.get(idx, {})
	if data.is_empty():
		return

	var state_res: EnemySpriteState = states.get(data["state"])
	if state_res == null:
		return

	# Dimensions normalisées d'une frame dans la sheet
	var frame_w_norm: float = float(frame_width) / float(sprite_texture.get_width())
	var frame_h_norm: float = float(frame_height) / float(sprite_texture.get_height())

	# Offset UV vers la bonne colonne et la bonne ligne
	var u_offset: float = data["current_frame"] * frame_w_norm
	var v_offset: float = state_res.sheet_row * frame_h_norm

	multimesh.set_instance_custom_data(idx, Color(u_offset, v_offset, frame_w_norm, frame_h_norm))


func hide_instance(idx: int) -> void:
	## Cache une instance en la plaçant hors écran avec scale 0
	var t := Transform2D()
	t.x = Vector2.ZERO
	t.y = Vector2.ZERO
	t.origin = Vector2(-99999, -99999)
	multimesh.set_instance_transform_2d(idx, t)
