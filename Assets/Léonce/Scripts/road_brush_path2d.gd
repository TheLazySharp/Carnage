@tool
extends Path2D
class_name RoadBrushPath2D

@export var pixel_size: int = 4:
	set(value):
		pixel_size = value
		generate_all()

@export_group("Stamps principaux")
@export_dir var stamp_folder: String = ""
@export var stamp_spacing: int = 2:
	set(value):
		stamp_spacing = max(value, 1)
		generate_all()
@export var perpendicular_jitter: int = 0:
	set(value):
		perpendicular_jitter = value
		generate_all()
@export var constrain_rotation_90: bool = true:
	set(value):
		constrain_rotation_90 = value
		generate_all()
@export var allow_flip: bool = true:
	set(value):
		allow_flip = value
		generate_all()

@export_group("Détails / irrégularités")
@export_dir var detail_folder: String = ""
@export var detail_spacing: int = 14:
	set(value):
		detail_spacing = max(value, 1)
		generate_all()
@export var detail_scatter_radius: int = 6:
	set(value):
		detail_scatter_radius = value
		generate_all()
@export var detail_min_distance: int = 3:
	set(value):
		detail_min_distance = value
		generate_all()
@export var detail_spawn_chance: float = 0.6:
	set(value):
		detail_spawn_chance = clamp(value, 0.0, 1.0)
		generate_all()

@export_group("Apparence")
@export var stamp_color: Color = Color.WHITE:
	set(value):
		stamp_color = value
		if _stamp_layer != null:
			_stamp_layer.self_modulate = stamp_color
@export var detail_color: Color = Color.WHITE:
	set(value):
		detail_color = value
		if _detail_layer != null:
			_detail_layer.self_modulate = detail_color

@export var rng_seed: int = 0:
	set(value):
		rng_seed = value
		generate_all()

@export_tool_button("Générer") var generate_btn: Callable = generate_all

var _stamp_layer: CanvasGroup
var _detail_layer: CanvasGroup
var _stamp_textures: Array[Texture2D] = []
var _detail_textures: Array[Texture2D] = []
var _curve_signal_connected: bool = false


func _ready() -> void:
	_ensure_layers()
	_connect_curve_signal()
	generate_all()


func _connect_curve_signal() -> void:
	if curve != null and not _curve_signal_connected:
		curve.changed.connect(generate_all)
		_curve_signal_connected = true


func _ensure_layers() -> void:
	_stamp_layer = get_node_or_null("StampLayer")
	if _stamp_layer == null:
		_stamp_layer = CanvasGroup.new()
		_stamp_layer.name = "StampLayer"
		add_child(_stamp_layer)
		if Engine.is_editor_hint():
			_stamp_layer.owner = get_tree().edited_scene_root
	_stamp_layer.self_modulate = stamp_color

	_detail_layer = get_node_or_null("DetailLayer")
	if _detail_layer == null:
		_detail_layer = CanvasGroup.new()
		_detail_layer.name = "DetailLayer"
		add_child(_detail_layer)
		if Engine.is_editor_hint():
			_detail_layer.owner = get_tree().edited_scene_root
	_detail_layer.self_modulate = detail_color


func _load_folder(path: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
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


func generate_all() -> void:
	if not is_inside_tree():
		return
	_ensure_layers()
	_connect_curve_signal()

	if curve == null or curve.get_point_count() < 2:
		return

	_stamp_textures = _load_folder(stamp_folder)
	_detail_textures = _load_folder(detail_folder)

	_clear_layer(_stamp_layer)
	_clear_layer(_detail_layer)

	var length: float = curve.get_baked_length()
	if length <= 0.0:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	_generate_stamps(length, rng)
	_generate_details(length, rng)


func _clear_layer(layer: CanvasGroup) -> void:
	for child in layer.get_children():
		layer.remove_child(child)
		child.free()


func _generate_stamps(length: float, rng: RandomNumberGenerator) -> void:
	if _stamp_textures.is_empty():
		return

	var step: float = stamp_spacing * pixel_size
	var count: int = int(length / step)

	for i in range(count + 1):
		var dist: float = min(i * step, length)
		var xform: Transform2D = curve.sample_baked_with_rotation(dist)
		var pos: Vector2 = xform.origin
		var normal: Vector2 = xform.y

		var lateral: float = 0.0
		if perpendicular_jitter > 0:
			lateral = rng.randf_range(-perpendicular_jitter, perpendicular_jitter) * pixel_size

		var final_pos := _snap(pos + normal * lateral)
		_spawn_stamp(_stamp_layer, _stamp_textures, final_pos, rng)


func _generate_details(length: float, rng: RandomNumberGenerator) -> void:
	if _detail_textures.is_empty():
		return

	var step: float = detail_spacing * pixel_size
	var count: int = int(length / step)
	var placed: Array[Vector2] = []

	for i in range(count + 1):
		if rng.randf() > detail_spawn_chance:
			continue

		var dist: float = min(i * step, length)
		var xform: Transform2D = curve.sample_baked_with_rotation(dist)
		var pos: Vector2 = xform.origin
		var normal: Vector2 = xform.y

		var candidate: Vector2 = pos
		var found := false
		for attempt in range(15):
			var lateral: float = rng.randf_range(-detail_scatter_radius, detail_scatter_radius) * pixel_size
			var c := pos + normal * lateral

			if detail_min_distance <= 0:
				candidate = c
				found = true
				break

			var too_close := false
			var min_dist_px: float = detail_min_distance * pixel_size
			for existing in placed:
				if c.distance_to(existing) < min_dist_px:
					too_close = true
					break
			if not too_close:
				candidate = c
				found = true
				break

		if not found:
			continue

		var final_pos := _snap(candidate)
		placed.append(final_pos)
		_spawn_stamp(_detail_layer, _detail_textures, final_pos, rng)


func _spawn_stamp(layer: CanvasGroup, pool: Array[Texture2D], pos: Vector2, rng: RandomNumberGenerator) -> void:
	var tex: Texture2D = pool[rng.randi_range(0, pool.size() - 1)]
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.position = pos

	if constrain_rotation_90:
		spr.rotation = rng.randi_range(0, 3) * (PI / 2.0)
	else:
		spr.rotation = 0.0

	if allow_flip:
		spr.flip_h = rng.randi_range(0, 1) == 1
		spr.flip_v = rng.randi_range(0, 1) == 1

	layer.add_child(spr)


func _snap(pos: Vector2) -> Vector2:
	return (pos / pixel_size).round() * pixel_size
