extends Node2D
class_name TireMarkEmitter

enum RotationMode { NONE, RANDOM_90, FOLLOW_DIRECTION, FOLLOW_DIRECTION_45 }

## Au-delà de ce déplacement en une frame, on considère un téléport : pas de trace.
const TELEPORT_DISTANCE: float = 600.0

@export_group("Émission")
## Actif par défaut pour le POC. En jeu, à piloter depuis le script de la voiture :
## wheel.emitting = is_drifting
@export var emitting: bool = true:
	set(value):
		if value == emitting:
			return
		emitting = value
		_has_last_pos = false
		if not value and _layer != null and is_instance_valid(_layer):
			_layer.end_chunk()

@export_group("Stamps")
## Dossier de .tres (AtlasTexture, etc.). Ignoré si stamp_textures est rempli.
@export_dir var stamp_folder: String = ""
@export var stamp_textures: Array[Texture2D] = []
## Sert uniquement à aligner les positions sur ta grille de pixels.
@export var pixel_size: int = 1
## Distance entre deux stamps, en pixels réels.
@export_range(0.5, 64.0, 0.5, "or_greater") var spacing: float = 4.0
@export var spacing_jitter: float = 0.0
@export var perpendicular_jitter: float = 0.0
## FOLLOW_* : tes textures doivent être dessinées orientées vers la droite (+X).
@export var rotation_mode: RotationMode = RotationMode.RANDOM_90
@export var allow_flip: bool = true

@export_group("Durée de vie et couleur")
## Temps entre la fin de pose d'un tronçon et sa disparition complète.
@export_range(0.1, 30.0, 0.1, "or_greater") var lifetime: float = 4.0
## Part de lifetime pendant laquelle le tronçon garde son alpha plein avant de s'estomper.
## 0 = l'estompage commence tout de suite, 0.5 = il commence à la moitié de la durée de vie.
@export_range(0.0, 0.95, 0.01) var fade_delay_ratio: float = 0.3
## Couleur appliquée à tout le tronçon (alpha compris), mémorisée à sa création :
## la changer en jeu n'affecte que les nouvelles traces.
@export var tint: Color = Color.WHITE

@export_group("Performance")
## Longueur d'un tronçon, en pixels réels. Plus court = fondu plus fin mais plus de nodes.
@export_range(16.0, 512.0, 1.0, "or_greater") var chunk_length: float = 96.0
## Plafond de tronçons par émetteur : le plus ancien est supprimé au-delà.
@export_range(1, 200, 1) var max_chunks: int = 40
## true : les stamps d'un tronçon fusionnent sans s'assombrir (un CanvasGroup par tronçon).
## false : plus léger, mais les stamps semi-transparents qui se chevauchent s'assombrissent.
@export var merge_overlap: bool = true

@export_group("Rendu")
## Les traces sont ajoutées à la racine de la scène courante : ce z_index règle leur ordre de dessin.
@export var marks_z_index: int = 0

var _rng := RandomNumberGenerator.new()
var _textures: Array[Texture2D] = []
var _layer: MarkLayer = null

var _has_last_pos: bool = false
var _last_pos: Vector2 = Vector2.ZERO
var _carry: float = 0.0
var _next_gap: float = 0.0


func _ready() -> void:
	_rng.randomize()
	_load_textures()


func _exit_tree() -> void:
	# Les traces déjà posées finissent de s'estomper même si la voiture disparaît.
	if _layer != null and is_instance_valid(_layer):
		_layer.end_chunk()
		_layer.detached = true
	_layer = null


## Efface immédiatement toutes les traces de cet émetteur.
func clear_marks() -> void:
	if _layer != null and is_instance_valid(_layer):
		_layer.clear_all()


func _process(_delta: float) -> void:
	if emitting:
		_emit_along(global_position)
	else:
		_has_last_pos = false


func _emit_along(pos: Vector2) -> void:
	if not _has_last_pos:
		_last_pos = pos
		_has_last_pos = true
		_carry = 0.0
		_next_gap = 0.0

	var seg: Vector2 = pos - _last_pos
	var seg_len: float = seg.length()
	if seg_len < 0.001:
		return

	if seg_len > TELEPORT_DISTANCE:
		_has_last_pos = false
		if _layer != null and is_instance_valid(_layer):
			_layer.end_chunk()
		return

	var dir: Vector2 = seg / seg_len
	var walked: float = 0.0

	# Pose les stamps à intervalle régulier le long du trajet réel de la roue,
	# même si la voiture parcourt plusieurs espacements en une seule frame.
	while true:
		var needed: float = _next_gap - _carry
		if walked + needed > seg_len:
			_carry += seg_len - walked
			break
		walked += needed
		_place_stamp(_last_pos + dir * walked, dir, maxf(_next_gap, 0.001))
		_carry = 0.0
		_next_gap = _pick_gap()

	_last_pos = pos


func _pick_gap() -> float:
	var jitter: float = 0.0
	if spacing_jitter > 0.0:
		jitter = _rng.randf_range(-spacing_jitter, spacing_jitter)
	return maxf(spacing + jitter, 0.5)


func _place_stamp(world_pos: Vector2, dir: Vector2, advance: float) -> void:
	if _textures.is_empty():
		return

	var layer: MarkLayer = _ensure_layer()
	if layer == null:
		return
	_sync_layer(layer)

	var offset := Vector2.ZERO
	if perpendicular_jitter > 0.0:
		offset = Vector2(-dir.y, dir.x) * _rng.randf_range(-perpendicular_jitter, perpendicular_jitter)

	var snapped_pos: Vector2 = (world_pos + offset).snapped(Vector2(pixel_size, pixel_size))

	var item := StampItem.new()
	item.texture = _textures[_rng.randi_range(0, _textures.size() - 1)]
	item.position = layer.to_local(snapped_pos)

	match rotation_mode:
		RotationMode.NONE:
			item.rotation = 0.0
		RotationMode.RANDOM_90:
			item.rotation = _rng.randi_range(0, 3) * (PI / 2.0)
		RotationMode.FOLLOW_DIRECTION:
			item.rotation = dir.angle()
		RotationMode.FOLLOW_DIRECTION_45:
			item.rotation = snappedf(dir.angle(), PI / 4.0)

	if allow_flip:
		item.flip_h = _rng.randi_range(0, 1) == 1
		item.flip_v = _rng.randi_range(0, 1) == 1

	layer.add_stamp(item, advance, chunk_length)


func _ensure_layer() -> MarkLayer:
	if _layer != null and is_instance_valid(_layer):
		return _layer

	var host: Node = get_tree().current_scene
	if host == null:
		return null

	_layer = MarkLayer.new()
	_layer.name = "TireMarkLayer"
	host.add_child(_layer)
	return _layer


func _sync_layer(layer: MarkLayer) -> void:
	layer.life_seconds = lifetime
	layer.fade_delay_ratio = fade_delay_ratio
	layer.max_chunks = max_chunks
	layer.merge_overlap = merge_overlap
	layer.current_tint = tint
	layer.z_index = marks_z_index


func _load_textures() -> void:
	_textures.clear()
	for tex: Texture2D in stamp_textures:
		if tex != null:
			_textures.append(tex)
	if _textures.is_empty() and not stamp_folder.is_empty():
		_textures = _load_folder(stamp_folder)
	if _textures.is_empty():
		push_warning("TireMarkEmitter2D: aucune texture (stamp_textures ou stamp_folder).")


func _load_folder(path: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	if not DirAccess.dir_exists_absolute(path):
		return result
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			# ".remap" : suffixe ajouté aux ressources dans un projet exporté.
			var clean_name: String = file_name.trim_suffix(".remap")
			var ext: String = clean_name.get_extension()
			if ext == "tres" or ext == "res":
				var res: Resource = load(path.path_join(clean_name))
				if res is Texture2D:
					result.append(res as Texture2D)
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a: Texture2D, b: Texture2D) -> bool: return a.resource_path < b.resource_path)
	return result


# ----------------------------------------------------------------------------
# Classes internes
# ----------------------------------------------------------------------------

class StampItem:
	var texture: Texture2D
	var position: Vector2 = Vector2.ZERO
	var rotation: float = 0.0
	var flip_h: bool = false
	var flip_v: bool = false


## Dessine tous les stamps d'un tronçon en un seul node.
class ChunkSurface extends Node2D:
	var items: Array[StampItem] = []

	func add_item(item: StampItem) -> void:
		items.append(item)
		queue_redraw()

	func _draw() -> void:
		for item: StampItem in items:
			if item.texture == null:
				continue
			var tex_size: Vector2 = item.texture.get_size()
			# Décalage entier : garde tous les coins sur des pixels entiers, même pour
			# des textures de taille impaire, avec rotations de 90° et flips.
			var half := Vector2(floorf(tex_size.x * 0.5), floorf(tex_size.y * 0.5))
			var flip_scale := Vector2(-1.0 if item.flip_h else 1.0, -1.0 if item.flip_v else 1.0)
			draw_set_transform(item.position, item.rotation, flip_scale)
			draw_texture(item.texture, -half)


class Chunk:
	var root: CanvasItem
	var surface: ChunkSurface
	var fade_node: CanvasItem
	var tint: Color = Color.WHITE
	var last_stamp_time: float = 0.0
	var length: float = 0.0
	var closed: bool = false


## Conteneur des tronçons d'un émetteur : gère leur création, leur vieillissement
## et leur suppression, même si l'émetteur (la voiture) a disparu entre-temps.
class MarkLayer extends Node2D:
	var chunks: Array[Chunk] = []
	var current: Chunk = null
	var clock: float = 0.0
	var life_seconds: float = 4.0
	var fade_delay_ratio: float = 0.3
	var max_chunks: int = 40
	var merge_overlap: bool = true
	var current_tint: Color = Color.WHITE
	var detached: bool = false

	func add_stamp(item: StampItem, advance: float, chunk_len: float) -> void:
		if current == null or current.closed:
			_begin_chunk()
		current.surface.add_item(item)
		current.last_stamp_time = clock
		current.length += advance
		if current.length >= chunk_len:
			end_chunk()

	func end_chunk() -> void:
		if current != null:
			current.closed = true
		current = null

	func clear_all() -> void:
		for chunk: Chunk in chunks:
			chunk.root.queue_free()
		chunks.clear()
		current = null

	func _begin_chunk() -> void:
		if max_chunks > 0 and chunks.size() >= max_chunks:
			_drop_oldest()

		var chunk := Chunk.new()
		var surface := ChunkSurface.new()
		if merge_overlap:
			var group := CanvasGroup.new()
			add_child(group)
			group.add_child(surface)
			chunk.root = group
			chunk.fade_node = group
		else:
			add_child(surface)
			chunk.root = surface
			chunk.fade_node = surface
		chunk.surface = surface
		chunk.tint = current_tint
		chunk.last_stamp_time = clock
		chunk.fade_node.self_modulate = current_tint
		chunks.append(chunk)
		current = chunk

	func _drop_oldest() -> void:
		if chunks.is_empty():
			return
		var oldest: Chunk = chunks[0]
		if oldest == current:
			current = null
		oldest.root.queue_free()
		chunks.remove_at(0)

	func _process(delta: float) -> void:
		clock += delta
		var life: float = maxf(life_seconds, 0.001)

		# Les tronçons sont triés du plus ancien au plus récent.
		while not chunks.is_empty():
			var first: Chunk = chunks[0]
			if clock - first.last_stamp_time < life:
				break
			_drop_oldest()

		var delay: float = clampf(fade_delay_ratio, 0.0, 0.95)

		for chunk: Chunk in chunks:
			var t: float = clampf((clock - chunk.last_stamp_time) / life, 0.0, 1.0)
			var alpha: float = 1.0
			if t > delay:
				alpha = 1.0 - (t - delay) / (1.0 - delay)
			var c: Color = chunk.tint
			c.a *= alpha
			chunk.fade_node.self_modulate = c

		if detached and chunks.is_empty():
			queue_free()
