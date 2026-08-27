@tool
extends Path2D
class_name RoadBrushPath2D

@export var pixel_size: int = 1:
	set(value):
		pixel_size = value
		generate_all()

@export_group("Main Stamps")
#@export_dir var stamp_folder: String = ""
@export var _stamp_textures : Array[Texture2D]
#@export var _line_textures : Array[Texture2D]

## Spacing between two stamps, randomized per stamp within [min, max].
@export var stamp_spacing_min: int = 2:
	set(value):
		stamp_spacing_min = max(value, 1)
		stamp_spacing_max = max(stamp_spacing_max, stamp_spacing_min)
		generate_all()
@export var stamp_spacing_max: int = 4:
	set(value):
		stamp_spacing_max = max(value, stamp_spacing_min)
		generate_all()
## Lateral offset amplitude, randomized per stamp within [min, max],
## then applied on a random side. Set min to 0 for a plain jitter.
@export var perpendicular_jitter_min: int = 0:
	set(value):
		perpendicular_jitter_min = max(value, 0)
		perpendicular_jitter_max = max(perpendicular_jitter_max, perpendicular_jitter_min)
		generate_all()
@export var perpendicular_jitter_max: int = 0:
	set(value):
		perpendicular_jitter_max = max(value, perpendicular_jitter_min)
		generate_all()
		
@export var constrain_rotation_90: bool = true:
	set(value):
		constrain_rotation_90 = value
		generate_all()
@export var allow_flip: bool = true:
	set(value):
		allow_flip = value
		generate_all()

@export_group("Grain")
#@export_dir var detail_folder: String = ""
@export var _detail_textures : Array[Texture2D]
@export var detail_spacing: int = 14:
	set(value):
		detail_spacing = max(value, 1)
		generate_all()
## Nombre de tentatives de spawn de détail à chaque point d'échantillonnage.
## Augmente pour un grain plus dense sans resserrer detail_spacing.
@export_range(1, 20, 1) var details_per_step: int = 1:
	set(value):
		details_per_step = max(value, 1)
		generate_all()
@export var detail_scatter_radius: int = 6:
	set(value):
		detail_scatter_radius = value
		generate_all()
@export var detail_min_distance: int = 3:
	set(value):
		detail_min_distance = value
		generate_all()
## Probabilité de spawn appliquée à CHAQUE tentative individuelle
## (donc à chacune des details_per_step tentatives par point).
@export_range(0.0, 1.0, 0.01) var detail_spawn_chance: float = 0.6:
	set(value):
		detail_spawn_chance = clamp(value, 0.0, 1.0)
		generate_all()
## 1.0 = distribution uniforme sur toute la largeur (comportement par défaut).
## > 1.0 = concentre davantage de détails près de l'axe central du Path2D.
## < 1.0 = au contraire, favorise les bords plutôt que le centre.
@export_range(0.2, 5.0, 0.05) var detail_radial_bias: float = 1.0:
	set(value):
		detail_radial_bias = value
		generate_all()

@export_group("Extremity Fade")
@export var fade_start_length: int = 0:
	set(value):
		fade_start_length = max(value, 0)
		generate_all()
@export var fade_end_length: int = 0:
	set(value):
		fade_end_length = max(value, 0)
		generate_all()
@export_range(0.2, 5.0, 0.05) var fade_curve_power: float = 1.0:
	set(value):
		fade_curve_power = value
		generate_all()

@export_group("Wear Line")
@export var wear_lines: Array[RoadWearLine] = []:
	set(value):
		wear_lines = value
		_connect_wear_line_signals()
		generate_all()
@export_tool_button("Add Wear Line") var add_wear_line_btn: Callable = _add_wear_line

@export_group("Appearence")
@export var stamp_color: Color = Color.WHITE:
	set(value):
		stamp_color = value
		if _stamp_layer != null:
			_stamp_layer.modulate = stamp_color
@export var detail_color: Color = Color.WHITE:
	set(value):
		detail_color = value
		if _detail_layer != null:
			_detail_layer.modulate = detail_color

@export var rng_seed: int = 0:
	set(value):
		rng_seed = value
		generate_all()

@export_tool_button("Generate") var generate_btn: Callable = generate_all

var _stamp_layer: Node2D
var _detail_layer: Node2D
#var _stamp_textures: Array[Texture2D] = []
#var _detail_textures: Array[Texture2D] = []
var _curve_signal_connected: bool = false

var _spatial_grid: Dictionary = {}
var _grid_cell_size: float = 1.0

var _path_length: float = 0.0


func _ready() -> void:
	_ensure_layers()
	_connect_curve_signal()
	_connect_wear_line_signals()
	generate_all()


func _connect_curve_signal() -> void:
	if curve != null and not _curve_signal_connected:
		curve.changed.connect(generate_all)
		_curve_signal_connected = true


func _connect_wear_line_signals() -> void:
	for line in wear_lines:
		if line != null and not line.changed.is_connected(generate_all):
			line.changed.connect(generate_all)


func _add_wear_line() -> void:
	var new_line := RoadWearLine.new()
	wear_lines.append(new_line)
	_connect_wear_line_signals()
	notify_property_list_changed()
	generate_all()


func _ensure_layers() -> void:
	_stamp_layer = get_node_or_null("StampLayer")
	if _stamp_layer == null:
		_stamp_layer = Node2D.new()
		_stamp_layer.name = "StampLayer"
		add_child(_stamp_layer)
		if Engine.is_editor_hint():
			_stamp_layer.owner = get_tree().edited_scene_root
	_stamp_layer.modulate = stamp_color

	_detail_layer = get_node_or_null("DetailLayer")
	if _detail_layer == null:
		_detail_layer = Node2D.new()
		_detail_layer.name = "DetailLayer"
		add_child(_detail_layer)
		if Engine.is_editor_hint():
			_detail_layer.owner = get_tree().edited_scene_root
	_detail_layer.modulate = detail_color


func generate_all() -> void:
	if not is_inside_tree():
		return
	_ensure_layers()
	_connect_curve_signal()
	_connect_wear_line_signals()

	if curve == null or curve.get_point_count() < 2:
		return


	_clear_layer(_stamp_layer)
	_clear_layer(_detail_layer)
	_clear_wear_line_layers()

	_path_length = curve.get_baked_length()
	if _path_length <= 0.0:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	_generate_stamps(rng)
	_generate_details(rng)
	_generate_wear_lines()


func _clear_layer(layer: Node2D) -> void:
	for child in layer.get_children():
		layer.remove_child(child)
		child.free()


func _clear_wear_line_layers() -> void:
	for child in get_children():
		if child.name.begins_with("WearLine_"):
			remove_child(child)
			child.free()


func _compute_fade(dist: float, fade_start: float, fade_end: float, curve_power: float) -> float:
	var factor: float = 1.0

	if fade_start > 0.0 and dist < fade_start:
		factor = min(factor, pow(dist / fade_start, curve_power))

	if fade_end > 0.0:
		var dist_from_end: float = _path_length - dist
		if dist_from_end < fade_end:
			factor = min(factor, pow(dist_from_end / fade_end, curve_power))

	return clamp(factor, 0.0, 1.0)


func _fade_probability(dist: float) -> float:
	return _compute_fade(dist, fade_start_length, fade_end_length, fade_curve_power)


func _generate_stamps(rng: RandomNumberGenerator) -> void:
	if _stamp_textures.is_empty():
		return
	var dist: float = 0.0
	while dist <= _path_length:
		var fade: float = _fade_probability(dist)
		if fade >= 1.0 or rng.randf() <= fade:
			var xform: Transform2D = curve.sample_baked_with_rotation(dist)
			var pos: Vector2 = xform.origin
			var normal: Vector2 = xform.y
			var lateral: float = 0.0
			if perpendicular_jitter_max > 0:
				# amplitude in [min, max], random side
				var amplitude: float = rng.randf_range(float(perpendicular_jitter_min), float(perpendicular_jitter_max))
				var side: float = 1.0 if rng.randf() < 0.5 else -1.0
				lateral = amplitude * side * pixel_size
			var final_pos: Vector2 = _snap(pos + normal * lateral)
			_spawn_stamp(_stamp_layer, _stamp_textures, final_pos, rng, constrain_rotation_90, allow_flip)
		dist += float(rng.randi_range(stamp_spacing_min, stamp_spacing_max)) * pixel_size


func _generate_details(rng: RandomNumberGenerator) -> void:
	if _detail_textures.is_empty():
		return

	var step: float = detail_spacing * pixel_size
	var count: int = int(_path_length / step)
	var min_dist_px: float = max(detail_min_distance * pixel_size, 1.0)

	_grid_reset(min_dist_px)

	for i in range(count + 1):
		var dist: float = min(i * step, _path_length)
		var fade: float = _fade_probability(dist)

		var xform: Transform2D = curve.sample_baked_with_rotation(dist)
		var pos: Vector2 = xform.origin
		var normal: Vector2 = xform.y

		for attempt_index in range(details_per_step):
			if rng.randf() > detail_spawn_chance * fade:
				continue

			var candidate: Vector2 = pos
			var found := false
			for attempt in range(15):
				var lateral: float = _biased_lateral(detail_scatter_radius * pixel_size, rng)
				var c := pos + normal * lateral

				if detail_min_distance <= 0:
					candidate = c
					found = true
					break

				if not _grid_has_neighbor_within(c, min_dist_px):
					candidate = c
					found = true
					break

			if not found:
				continue

			var final_pos := _snap(candidate)
			_grid_insert(final_pos)
			_spawn_stamp(_detail_layer, _detail_textures, final_pos, rng, constrain_rotation_90, allow_flip)


func _generate_wear_lines() -> void:
	for i in range(wear_lines.size()):
		var line: RoadWearLine = wear_lines[i]
		if line == null:
			continue
		_generate_single_wear_line(line, i)


func _generate_single_wear_line(line: RoadWearLine, index: int) -> void:
	var textures : Array[Texture2D] = line.textures
	if textures.is_empty():
		push_warning("[WearLine %d] no texture in the resource" % index)
		return

	var layer := Node2D.new()
	layer.name = "WearLine_%d" % index
	add_child(layer)
	if Engine.is_editor_hint():
		layer.owner = get_tree().edited_scene_root
	layer.self_modulate = line.color

	var rng := RandomNumberGenerator.new()
	##Mixing the path's own rng_seed
	rng.seed = hash(str(rng_seed, ":", line.line_seed, ":", index)) 
	var step: float = line.spacing * pixel_size
	var avg_gap_steps: float = max((line.avg_gap_length * pixel_size) / step, 1.0)
	var avg_active_steps: float = max(avg_gap_steps * (line.coverage_ratio / max(1.0 - line.coverage_ratio, 0.001)), 1.0)
	var prob_leave_active: float = 1.0 / avg_active_steps
	var prob_leave_gap: float = 1.0 / avg_gap_steps
	var state_active: bool = rng.randf() < line.coverage_ratio
	var dist: float = rng.randf() * step
	var spawned: int = 0
	var rejected_fade: int = 0
	while dist <= _path_length:
		var jitter: float = 0.0
		if line.spacing_jitter > 0.0:
			jitter = rng.randf_range(-line.spacing_jitter, line.spacing_jitter) * pixel_size
		var sample_dist: float = clamp(dist + jitter, 0.0, _path_length)
		if state_active:
			var fade: float = _compute_fade(sample_dist, line.fade_start_length, line.fade_end_length, line.fade_curve_power)
			if rng.randf() <= fade:
				var xform: Transform2D = curve.sample_baked_with_rotation(sample_dist)
				var pos: Vector2 = xform.origin
				var normal: Vector2 = xform.y
				var final_pos := _snap(pos + normal * line.perpendicular_offset * pixel_size)
				_spawn_stamp(layer, textures, final_pos, rng, line.constrain_rotation_90, line.allow_flip)
				spawned += 1
			else:
				rejected_fade += 1
			if rng.randf() < prob_leave_active:
				state_active = false
		else:
			if rng.randf() < prob_leave_gap:
				state_active = true
		dist += step

func _biased_lateral(radius: float, rng: RandomNumberGenerator) -> float:
	var t: float = rng.randf()
	var shaped: float = pow(t, detail_radial_bias)
	var sign_val: float = 1.0 if rng.randf() < 0.5 else -1.0
	return sign_val * shaped * radius


func _grid_reset(cell_size: float) -> void:
	_spatial_grid.clear()
	_grid_cell_size = max(cell_size, 1.0)


func _grid_cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / _grid_cell_size), floori(pos.y / _grid_cell_size))


func _grid_insert(pos: Vector2) -> void:
	var cell := _grid_cell_of(pos)
	if not _spatial_grid.has(cell):
		_spatial_grid[cell] = []
	_spatial_grid[cell].append(pos)


func _grid_has_neighbor_within(pos: Vector2, min_dist: float) -> bool:
	var center_cell := _grid_cell_of(pos)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var cell := center_cell + Vector2i(dx, dy)
			if not _spatial_grid.has(cell):
				continue
			for existing: Vector2 in _spatial_grid[cell]:
				if pos.distance_to(existing) < min_dist:
					return true
	return false


func _spawn_stamp(layer: Node2D, pool: Array[Texture2D], pos: Vector2, rng: RandomNumberGenerator, constrain_90: bool, flip: bool) -> void:
	var tex: Texture2D = pool[rng.randi_range(0, pool.size() - 1)]
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.position = pos

	if constrain_90:
		spr.rotation = rng.randi_range(0, 3) * (PI / 2.0)
	else:
		spr.rotation = 0.0

	if flip:
		spr.flip_h = rng.randi_range(0, 1) == 1
		spr.flip_v = rng.randi_range(0, 1) == 1

	layer.add_child(spr)


func _snap(pos: Vector2) -> Vector2:
	return (pos / pixel_size).round() * pixel_size
