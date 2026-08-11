@tool
extends Path2D
class_name RoadMarkingPath2D

@export var pixel_size: int = 4:
	set(value):
		pixel_size = max(value, 1)
		generate_all()

@export var lines: Array[RoadMarkingLine] = []:
	set(value):
		lines = value
		_connect_line_signals()
		generate_all()
@export_tool_button("Ajouter une ligne") var add_line_btn: Callable = _add_line

@export_tool_button("Générer") var generate_btn: Callable = generate_all

var _curve_signal_connected: bool = false
var _path_length: float = 0.0


func _ready() -> void:
	_connect_curve_signal()
	_connect_line_signals()
	generate_all()


func _connect_curve_signal() -> void:
	if curve != null and not _curve_signal_connected:
		curve.changed.connect(generate_all)
		_curve_signal_connected = true


func _connect_line_signals() -> void:
	for line in lines:
		if line != null and not line.changed.is_connected(generate_all):
			line.changed.connect(generate_all)


func _add_line() -> void:
	var new_line := RoadMarkingLine.new()
	lines.append(new_line)
	_connect_line_signals()
	notify_property_list_changed()
	generate_all()


func generate_all() -> void:
	if not is_inside_tree():
		return
	_connect_curve_signal()
	_connect_line_signals()
	_clear_previous()

	if curve == null or curve.get_point_count() < 2:
		return

	_path_length = curve.get_baked_length()
	if _path_length <= 0.0:
		return

	for i in range(lines.size()):
		var line: RoadMarkingLine = lines[i]
		if line != null:
			_generate_single_line(line, i)


func _clear_previous() -> void:
	for child in get_children():
		if child.name.begins_with("MarkingLine_"):
			remove_child(child)
			child.free()


func _generate_single_line(line: RoadMarkingLine, index: int) -> void:
	var layer := CanvasGroup.new()
	layer.name = "MarkingLine_%d" % index
	add_child(layer)
	if Engine.is_editor_hint():
		layer.owner = get_tree().edited_scene_root
	layer.self_modulate = line.color

	var fill_surface := DrawSurface2D.new()
	fill_surface.name = "FillSurface"
	layer.add_child(fill_surface)
	if Engine.is_editor_hint():
		fill_surface.owner = get_tree().edited_scene_root

	var rng := RandomNumberGenerator.new()
	rng.seed = line.line_seed

	var half_thick: float = (line.thickness * pixel_size) / 2.0
	var offset: float = line.perpendicular_offset * pixel_size

	var cell_dict: Dictionary = {}

	var dist: float = 0.0
	var cycle: float = line.dash_length + line.gap_length

	while dist < _path_length:
		var dash_start: float = dist
		var dash_end: float = min(dist + line.dash_length, _path_length)

		if dash_end > dash_start:
			var start_xform: Transform2D = curve.sample_baked_with_rotation(dash_start)
			var end_xform: Transform2D = curve.sample_baked_with_rotation(dash_end)

			var start_pos: Vector2 = start_xform.origin + start_xform.y * offset
			var end_pos: Vector2 = end_xform.origin + end_xform.y * offset

			var frame := _dash_frame(start_pos, end_pos, half_thick)
			if not frame.is_empty():
				var seeds: Array = []
				if line.enable_wear:
					seeds = _generate_bite_seeds(frame, line, rng)

				var cells := _rasterize_dash(frame, seeds)

				if line.enable_wear and line.interior_wear_density > 0.0:
					cells = _apply_interior_wear(cells, line, rng)

				for c in cells:
					cell_dict[c] = true

		dist += cycle

	var items: Array = []
	for c: Vector2i in cell_dict.keys():
		items.append({"type": "rect", "pos": Vector2(c) * pixel_size, "size": Vector2(pixel_size, pixel_size)})

	fill_surface.set_items(items)


func _dash_frame(start_pos: Vector2, end_pos: Vector2, half_thick: float) -> Dictionary:
	var chord: Vector2 = end_pos - start_pos
	var length: float = chord.length()
	if length < 0.001:
		return {}

	var dir: Vector2 = chord / length
	var normal := Vector2(-dir.y, dir.x)
	var center: Vector2 = (start_pos + end_pos) / 2.0

	return {
		"dir": dir,
		"normal": normal,
		"length": length,
		"center": center,
		"half_thick": half_thick,
	}


func _rasterize_dash(frame: Dictionary, seeds: Array) -> Array[Vector2i]:
	var dir: Vector2 = frame["dir"]
	var normal: Vector2 = frame["normal"]
	var length: float = frame["length"]
	var center: Vector2 = frame["center"]
	var half_thick: float = frame["half_thick"]

	var half_len: float = length / 2.0
	var corners: Array[Vector2] = [
		center + dir * half_len + normal * half_thick,
		center + dir * half_len - normal * half_thick,
		center - dir * half_len + normal * half_thick,
		center - dir * half_len - normal * half_thick,
	]

	var min_x: float = corners[0].x
	var max_x: float = corners[0].x
	var min_y: float = corners[0].y
	var max_y: float = corners[0].y
	for c in corners:
		min_x = min(min_x, c.x)
		max_x = max(max_x, c.x)
		min_y = min(min_y, c.y)
		max_y = max(max_y, c.y)

	var cell_min_x: int = floori(min_x / pixel_size) - 1
	var cell_max_x: int = ceili(max_x / pixel_size) + 1
	var cell_min_y: int = floori(min_y / pixel_size) - 1
	var cell_max_y: int = ceili(max_y / pixel_size) + 1

	var result: Array[Vector2i] = []

	for cx in range(cell_min_x, cell_max_x + 1):
		for cy in range(cell_min_y, cell_max_y + 1):
			var cell_center := Vector2((cx + 0.5) * pixel_size, (cy + 0.5) * pixel_size)
			var rel: Vector2 = cell_center - center
			var along: float = rel.dot(dir)
			var perp: float = rel.dot(normal)

			if abs(along) > half_len or abs(perp) > half_thick:
				continue

			var eroded := false
			for seed: Dictionary in seeds:
				if cell_center.distance_to(seed["pos"]) < seed["radius"]:
					eroded = true
					break

			if not eroded:
				result.append(Vector2i(cx, cy))

	return result


## Retire aléatoirement des cellules isolées (ou en paire) N'IMPORTE OÙ dans
## le tiret, bord ou intérieur -- simule les petits trous/écailles au milieu
## du marquage, pas seulement le grignotage des bords.
func _apply_interior_wear(cells: Array[Vector2i], line: RoadMarkingLine, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var cell_set: Dictionary = {}
	for c in cells:
		cell_set[c] = true

	var to_remove: Dictionary = {}
	var neighbor_dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	for c in cells:
		if rng.randf() < line.interior_wear_density:
			to_remove[c] = true
			if rng.randf() < line.interior_wear_pair_chance:
				var nb: Vector2i = c + neighbor_dirs[rng.randi_range(0, 3)]
				if cell_set.has(nb):
					to_remove[nb] = true

	var result: Array[Vector2i] = []
	for c in cells:
		if not to_remove.has(c):
			result.append(c)

	return result


func _generate_bite_seeds(frame: Dictionary, line: RoadMarkingLine, rng: RandomNumberGenerator) -> Array:
	var dir: Vector2 = frame["dir"]
	var normal: Vector2 = frame["normal"]
	var length: float = frame["length"]
	var center: Vector2 = frame["center"]
	var half_thick: float = frame["half_thick"]

	var seeds: Array = []
	var step: float = line.wear_spacing * pixel_size
	var steps: int = max(int(length / step), 1)

	for i in range(steps + 1):
		var t: float = (float(i) / steps - 0.5) * length

		if rng.randf() < line.wear_density:
			var radius: float = rng.randf_range(line.wear_bite_min, line.wear_bite_max) * pixel_size
			var pos: Vector2 = center + dir * t + normal * half_thick
			seeds.append({"pos": pos, "radius": radius})

		if rng.randf() < line.wear_density:
			var radius2: float = rng.randf_range(line.wear_bite_min, line.wear_bite_max) * pixel_size
			var pos2: Vector2 = center + dir * t - normal * half_thick
			seeds.append({"pos": pos2, "radius": radius2})

	return seeds


func _snap(pos: Vector2) -> Vector2:
	return (pos / pixel_size).round() * pixel_size
