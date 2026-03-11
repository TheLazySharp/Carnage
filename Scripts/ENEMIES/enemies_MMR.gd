## ZombieMultiMeshRenderer.gd
##
## Nœud central qui remplace tous les AnimatedSprite2D des zombies.
## Un seul draw call GPU pour tous les zombies.
##
## SETUP DANS L'ÉDITEUR :
##   1. Ajouter un nœud MultiMeshInstance2D dans la scène (enfant de World)
##   2. Attacher ce script dessus
##   3. Assigner la texture (spritesheet) dans l'inspecteur
##   4. Les states sont préconfigurés mais éditables dans l'inspecteur
##
## SPRITESHEET ATTENDUE :
##   - Chaque ligne = un état (walk ligne 0, attack ligne 1, etc.)
##   - Chaque colonne = une frame
##   - Taille par frame : frame_width x frame_height pixels
##
## POUR AJOUTER UN ÉTAT VISUEL :
##   1. Ajouter une nouvelle ligne à ta spritesheet
##   2. Créer un ZombieSpriteState (sheet_row = nouvelle ligne, frame_count = nb frames)
##   3. L'ajouter dans le dictionnaire states via _setup_default_states() ou l'inspecteur

class_name ZombieMultiMeshRenderer
extends MultiMeshInstance2D

# ─────────────────────────────────────────────
#  CONFIGURATION SPRITESHEET
# ─────────────────────────────────────────────

## Texture spritesheet à assigner dans l'inspecteur
@export var sprite_texture: Texture2D

## Largeur d'une frame en pixels
@export var frame_width: int = 90

## Hauteur d'une frame en pixels
@export var frame_height: int = 90

## Nombre maximum de zombies supportés (dimensionne le MultiMesh)
@export var max_instances: int = 1000

# ─────────────────────────────────────────────
#  ÉTATS D'ANIMATION
# ─────────────────────────────────────────────

## États disponibles. Clé = nom de l'état, Valeur = ZombieSpriteState.
## Rempli automatiquement par _setup_default_states().
## Tu peux aussi les surcharger dans l'inspecteur.
var states: Dictionary = {}

# ─────────────────────────────────────────────
#  DONNÉES INTERNES PAR INSTANCE
# ─────────────────────────────────────────────

# Tableau des ennemis enregistrés (index = instance MultiMesh)
var _registered_enemies: Array = []

# Index libre pour attribution rapide
var _free_indices: Array[int] = []

# Données d'animation par instance
# Clé = instance_index, Valeur = { state, current_frame, timer, enemy_ref }
var _instance_data: Dictionary = {}

# Dimensions de la spritesheet en nombre de frames
var _sheet_cols: int = 0   # calculé depuis frame_width et texture
var _sheet_rows: int = 0   # calculé depuis frame_height et texture

# ─────────────────────────────────────────────
#  INITIALISATION
# ─────────────────────────────────────────────

func _ready() -> void:
	_setup_default_states()
	_setup_multimesh()


func _setup_default_states() -> void:
	## Définit les états par défaut.
	## POUR AJOUTER UN ÉTAT : dupliquer le bloc ci-dessous avec le bon sheet_row.

	var walk_state := ZombieSpriteState.new()
	walk_state.state_name = "walk"
	walk_state.sheet_row = 0
	walk_state.frame_count = 10
	walk_state.fps = 10.0
	walk_state.loop = true
	states["walk"] = walk_state

	# Exemple d'état futur (décommenter et adapter quand ta spritesheet aura une 2e ligne) :
	#
	# var attack_state := ZombieSpriteState.new()
	# attack_state.state_name = "attack"
	# attack_state.sheet_row = 1
	# attack_state.frame_count = 6
	# attack_state.fps = 12.0
	# attack_state.loop = false
	# states["attack"] = attack_state
	#
	# var death_state := ZombieSpriteState.new()
	# death_state.state_name = "death"
	# death_state.sheet_row = 2
	# death_state.frame_count = 8
	# death_state.fps = 8.0
	# death_state.loop = false
	# states["death"] = death_state


func _setup_multimesh() -> void:
	if sprite_texture == null:
		push_error("ZombieMultiMeshRenderer : sprite_texture non assignée !")
		return

	# Calculer les dimensions de la sheet
	_sheet_cols = int(sprite_texture.get_width()) / frame_width
	_sheet_rows = int(sprite_texture.get_height()) / frame_height

	# Créer le QuadMesh aux bonnes dimensions
	var quad := QuadMesh.new()
	quad.size = Vector2(frame_width, frame_height)
	
	# Créer et configurer le MultiMesh
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true   # canal custom_data pour l'UV (frame + row)
	mm.instance_count = max_instances
	mm.mesh = quad

	multimesh = mm
	texture = sprite_texture

	# Créer le matériau avec shader UV
	var mat := ShaderMaterial.new()
	mat.shader = _create_sprite_sheet_shader()
	material = mat

	# Pré-remplir les indices libres
	_free_indices.resize(max_instances)
	for i in range(max_instances):
		_free_indices[i] = max_instances - 1 - i   # stack LIFO

	# Cacher toutes les instances (scale 0)
	for i in range(max_instances):
		_hide_instance(i)


func _create_sprite_sheet_shader() -> Shader:
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
	COLOR = col * COLOR;
}
"""
	return shader

# ─────────────────────────────────────────────
#  API PUBLIQUE — appelée par les ennemis
# ─────────────────────────────────────────────

## Enregistre un ennemi dans le renderer. Retourne son instance_index.
## À appeler dans Enemy._ready()
func register_enemy(enemy: Enemy) -> int:
	if _free_indices.is_empty():
		push_warning("ZombieMultiMeshRenderer : max_instances atteint !")
		return -1

	var idx: int = _free_indices.pop_back()
	
	_instance_data[idx] = {
		"enemy": enemy,
		"state": "walk",
		"current_frame": 0,
		"timer": 0.0,
		"flip_h": false
	}

	_update_instance_transform(idx, enemy.global_position, enemy.rotation)
	_update_instance_uv(idx)
	return idx


## Libère un ennemi du renderer (à appeler dans on_death, avant queue_free)
func unregister_enemy(instance_index: int) -> void:
	if instance_index < 0:
		return
	_hide_instance(instance_index)
	_instance_data.erase(instance_index)
	_free_indices.push_back(instance_index)


## Change l'état d'animation d'un ennemi.
## ex: renderer.set_enemy_state(my_index, "attack")
func set_enemy_state(instance_index: int, state_name: String) -> void:
	if instance_index < 0:
		return
	if not states.has(state_name):
		push_warning("ZombieMultiMeshRenderer : état inconnu : " + state_name)
		return
	var data: Dictionary = _instance_data.get(instance_index, {})
	if data.is_empty():
		return
	if data["state"] == state_name:
		return
	data["state"] = state_name
	data["current_frame"] = 0
	data["timer"] = 0.0


# ─────────────────────────────────────────────
#  BOUCLE PRINCIPALE
# ─────────────────────────────────────────────

func _process(delta: float) -> void:
	if multimesh == null:
		return
	
	for idx : int in _instance_data:
		var data: Dictionary = _instance_data[idx]
		var enemy: Enemy = data["enemy"]

		if not is_instance_valid(enemy):
			continue

		# --- Mise à jour de la position ---
		_update_instance_transform(idx, enemy.global_position, enemy.rotation)

		# --- Flip horizontal selon la direction ---
		var flip := enemy.velocity.x < 0
		if flip != data["flip_h"]:
			data["flip_h"] = flip
			# Le flip est géré via scale.x dans la transform

		# --- Avancement de l'animation ---
		var state_res: ZombieSpriteState = states.get(data["state"])
		if state_res == null:
			continue

		data["timer"] += delta
		var frame_duration: float = 1.0 / state_res.fps

		if data["timer"] >= frame_duration:
			data["timer"] -= frame_duration
			var next_frame: int = data["current_frame"] + 1

			if next_frame >= state_res.frame_count:
				if state_res.loop:
					next_frame = 0
				else:
					next_frame = state_res.frame_count - 1

			if next_frame != data["current_frame"]:
				data["current_frame"] = next_frame
				_update_instance_uv(idx)


# ─────────────────────────────────────────────
#  FONCTIONS INTERNES
# ─────────────────────────────────────────────

func _update_instance_transform(idx: int, pos: Vector2, rot: float) -> void:
	var t := Transform2D()
	t = t.rotated(rot)
	t.origin = pos

	# Flip horizontal si nécessaire
	var data: Dictionary = _instance_data.get(idx, {})
	if not data.is_empty() and data.get("flip_h", false):
		t.x = -t.x

	multimesh.set_instance_transform_2d(idx, t)


func _update_instance_uv(idx: int) -> void:
	var data: Dictionary = _instance_data.get(idx, {})
	if data.is_empty():
		return

	var state_res: ZombieSpriteState = states.get(data["state"])
	if state_res == null:
		return

	# Dimensions normalisées d'une frame dans la sheet
	var frame_w_norm: float = float(frame_width) / float(sprite_texture.get_width())
	var frame_h_norm: float = float(frame_height) / float(sprite_texture.get_height())

	# Offset UV vers la bonne colonne et la bonne ligne
	var u_offset: float = data["current_frame"] * frame_w_norm
	var v_offset: float = state_res.sheet_row * frame_h_norm

	multimesh.set_instance_custom_data(idx, Color(u_offset, v_offset, frame_w_norm, frame_h_norm))


func _hide_instance(idx: int) -> void:
	## Cache une instance en la plaçant hors écran avec scale 0
	var t := Transform2D()
	t.x = Vector2.ZERO
	t.y = Vector2.ZERO
	t.origin = Vector2(-99999, -99999)
	multimesh.set_instance_transform_2d(idx, t)
