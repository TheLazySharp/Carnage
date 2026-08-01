extends CanvasGroup
class_name BloodSplatter

@export_group("Dossiers des pools")
@export_dir var main_folder: String = "res://Assets/Blood/main"
@export_dir var big_folder: String = "res://Assets/Blood/big"
@export_dir var small_folder: String = "res://Assets/Blood/small"

@export_group("Quantités")
@export_range(1, 10, 1) var big_count_min: int = 1
@export_range(1, 10, 1) var big_count_max: int = 3
@export_range(1, 30, 1) var small_count_min: int = 3
@export_range(1, 30, 1) var small_count_max: int = 6

@export_group("Placement")
@export_range(1, 16, 1) var pixel_size: int = 1
@export_range(0, 128, 1) var big_scatter_radius: int = 8
@export_range(0, 256, 1) var small_scatter_radius: int = 14
@export_range(0, 64, 1) var min_distance: int = 3

## Décale le centre de dispersion des grosses taches le long de l'axe X local.
## Négatif = derrière la tache principale (sens opposé à la projection).
@export var big_scatter_offset: int = -4

## Idem pour les petites taches (généralement plus négatif).
@export var small_scatter_offset: int = -8

@export_group("Rotation (grosses/petites taches uniquement)")
@export var constrain_rotation_90: bool = false
@export var allow_flip: bool = true

@export_group("Timing")
## Durée totale sur laquelle toutes les taches apparaissent l'une après l'autre,
## triées de la valeur X locale la plus haute (spawn en premier) à la plus basse
## (spawn en dernier). 0 = toutes les taches apparaissent instantanément.
@export_range(0.0, 3.0, 0.01) var spawn_duration: float = 0.25

@export_group("Apparence")
@export var blood_color: Color = Color.WHITE:
	set(value):
		blood_color = value
		self_modulate = blood_color

var _rng := RandomNumberGenerator.new()
var _placed_positions: Array[Vector2] = []

var _main_textures: Array[Texture2D] = []
var _big_textures: Array[Texture2D] = []
var _small_textures: Array[Texture2D] = []


func _ready() -> void:
	_rng.randomize()
	self_modulate = blood_color

	_main_textures = _load_folder(main_folder)
	_big_textures = _load_folder(big_folder)
	_small_textures = _load_folder(small_folder)

	_spawn_sequence()


func face_direction(direction: Vector2) -> void:
	if direction.length_squared() > 0.0:
		rotation = direction.angle()


func _load_folder(path: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		push_warning("BloodSplatter: dossier introuvable : %s" % path)
		return result
	var dir := DirAccess.open(path)
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "tres":
			var res := load(path.path_join(file_name))
			if res is Texture2D:
				result.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a: Texture2D, b: Texture2D) -> bool: return a.resource_path < b.resource_path)
	return result


## Représente une tache à venir avant qu'elle ne soit réellement instanciée :
## on calcule toutes les positions d'abord, pour pouvoir trier par X avant de spawn.
class PendingSplat:
	var texture: Texture2D
	var position: Vector2


func _spawn_sequence() -> void:
	var pending: Array[PendingSplat] = []

	if not _main_textures.is_empty():
		var main_tex: Texture2D = _main_textures[_rng.randi_range(0, _main_textures.size() - 1)]
		pending.append(_make_pending(main_tex, Vector2.ZERO))
	else:
		push_warning("BloodSplatter: aucune texture dans main_folder.")

	if not _big_textures.is_empty():
		var big_center := Vector2(big_scatter_offset, 0) * pixel_size
		var big_count := _rng.randi_range(big_count_min, big_count_max)
		for i in range(big_count):
			var pos := big_center + _find_scatter_position(big_scatter_radius)
			var tex: Texture2D = _big_textures[_rng.randi_range(0, _big_textures.size() - 1)]
			pending.append(_make_pending(tex, pos))

	if not _small_textures.is_empty():
		var small_center := Vector2(small_scatter_offset, 0) * pixel_size
		var small_count := _rng.randi_range(small_count_min, small_count_max)
		for i in range(small_count):
			var pos := small_center + _find_scatter_position(small_scatter_radius)
			var tex: Texture2D = _small_textures[_rng.randi_range(0, _small_textures.size() - 1)]
			pending.append(_make_pending(tex, pos))

	# Tri par X local décroissant : la valeur la plus haute apparaît en premier.
	pending.sort_custom(func(a: PendingSplat, b: PendingSplat) -> bool: return a.position.x > b.position.x)

	if pending.is_empty():
		return

	var delay_between: float = spawn_duration / float(pending.size())
	for splat in pending:
		_instantiate_splat(splat)
		if delay_between > 0.0:
			await get_tree().create_timer(delay_between).timeout


func _make_pending(tex: Texture2D, pos: Vector2) -> PendingSplat:
	var p := PendingSplat.new()
	p.texture = tex
	p.position = pos
	_placed_positions.append(pos)  # réservé dès le calcul, pour que min_distance reste cohérent entre pools
	return p


func _find_scatter_position(radius: int) -> Vector2:
	var max_attempts := 20
	for attempt in range(max_attempts):
		var angle := _rng.randf_range(0, TAU)
		var dist := _rng.randf_range(0, radius) * pixel_size
		var candidate := Vector2(cos(angle), sin(angle)) * dist

		if min_distance <= 0:
			return _snap(candidate)

		var too_close := false
		var min_dist_px: float = min_distance * pixel_size
		for existing in _placed_positions:
			if candidate.distance_to(existing) < min_dist_px:
				too_close = true
				break
		if not too_close:
			return _snap(candidate)

	var fallback_angle := _rng.randf_range(0, TAU)
	return _snap(Vector2(cos(fallback_angle), sin(fallback_angle)) * radius * pixel_size)


func _snap(pos: Vector2) -> Vector2:
	if pixel_size <= 1:
		return pos.round()
	return (pos / pixel_size).round() * pixel_size


func _instantiate_splat(splat: PendingSplat) -> void:
	var spr := Sprite2D.new()
	spr.texture = splat.texture
	spr.position = splat.position

	# La tache principale (position exactement à l'origine) garde une orientation fixe.
	if splat.position == Vector2.ZERO:
		spr.rotation = 0.0
	else:
		if constrain_rotation_90:
			spr.rotation = _rng.randi_range(0, 3) * (PI / 2.0)
		else:
			spr.rotation = _rng.randf_range(0, TAU)
		if allow_flip:
			spr.flip_h = _rng.randi_range(0, 1) == 1
			spr.flip_v = _rng.randi_range(0, 1) == 1

	add_child(spr)
