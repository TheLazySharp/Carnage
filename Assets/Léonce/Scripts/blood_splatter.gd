extends Node2D
class_name BloodSplatter

@export_group("Dossiers des pools")
@export_dir var main_folder: String = "res://Assets/Blood/main"
@export_dir var big_folder: String = "res://Assets/Blood/big"
@export_dir var small_folder: String = "res://Assets/Blood/small"

@export_group("Quantités")
@export_range(1, 3, 1) var big_count_min: int = 1
@export_range(1, 3, 1) var big_count_max: int = 3
@export_range(1, 8, 1) var small_count_min: int = 3
@export_range(1, 8, 1) var small_count_max: int = 6

@export_group("Placement")
@export var pixel_size: int = 1
@export var big_scatter_radius: int = 8
@export var small_scatter_radius: int = 14
@export var min_distance: int = 3

@export_group("Rotation")
@export var constrain_rotation_90: bool = false
@export var allow_flip: bool = true

@export_group("Timing")
@export var delay_before_big: float = 0.05
@export var delay_before_small: float = 0.05

@export_group("Fusion (CanvasGroup)")
@export_range(0.0, 1.0, 0.01) var splatter_alpha: float = 1.0

var _rng := RandomNumberGenerator.new()
var _canvas_group: CanvasGroup
var _placed_positions: Array[Vector2] = []

var _main_textures: Array[Texture2D] = []
var _big_textures: Array[Texture2D] = []
var _small_textures: Array[Texture2D] = []


func _ready() -> void:
	_rng.randomize()
	_main_textures = _load_folder(main_folder)
	_big_textures = _load_folder(big_folder)
	_small_textures = _load_folder(small_folder)

	_canvas_group = CanvasGroup.new()
	_canvas_group.self_modulate = Color(1, 1, 1, splatter_alpha)
	add_child(_canvas_group)
	_spawn_sequence()


func _load_folder(path: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		push_warning("BloodSplatterEffect2D: dossier introuvable : %s" % path)
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


func _spawn_sequence() -> void:
	if not _main_textures.is_empty():
		_spawn_one(_main_textures, Vector2.ZERO)
	else:
		push_warning("BloodSplatterEffect2D: aucune texture dans main_folder.")

	await get_tree().create_timer(delay_before_big).timeout

	if not _big_textures.is_empty():
		var big_count := _rng.randi_range(big_count_min, big_count_max)
		for i in range(big_count):
			_spawn_one(_big_textures, _find_scatter_position(big_scatter_radius))

	await get_tree().create_timer(delay_before_small).timeout

	if not _small_textures.is_empty():
		var small_count := _rng.randi_range(small_count_min, small_count_max)
		for i in range(small_count):
			_spawn_one(_small_textures, _find_scatter_position(small_scatter_radius))

	var parent := get_parent()
	remove_child(_canvas_group)
	parent.add_child(_canvas_group)
	_canvas_group.global_position = global_position
	queue_free()


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


func _spawn_one(pool: Array[Texture2D], pos: Vector2) -> void:
	var tex: Texture2D = pool[_rng.randi_range(0, pool.size() - 1)]
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.position = pos

	if constrain_rotation_90:
		spr.rotation = _rng.randi_range(0, 3) * (PI / 2.0)
	else:
		spr.rotation = _rng.randf_range(0, TAU)

	if allow_flip:
		spr.flip_h = _rng.randi_range(0, 1) == 1
		spr.flip_v = _rng.randi_range(0, 1) == 1

	_canvas_group.add_child(spr)
	_placed_positions.append(pos)
