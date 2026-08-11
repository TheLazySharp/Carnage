@tool
extends CanvasGroup
class_name CrackNetworkGenerator

@export_group("Tracé principal")
@export var start_position: Vector2 = Vector2.ZERO:
	set(value):
		start_position = value
		generate()
@export_range(0.0, 360.0, 1.0) var start_angle_degrees: float = 0.0:
	set(value):
		start_angle_degrees = value
		generate()
@export var pixel_size: int = 1:
	set(value):
		pixel_size = max(value, 1)
		generate()
@export var total_length: int = 120:
	set(value):
		total_length = max(value, 1)
		generate()
@export var segment_length: int = 3:
	set(value):
		segment_length = max(value, 1)
		generate()
@export_range(0.0, 60.0, 0.5) var max_turn_degrees: float = 25.0:
	set(value):
		max_turn_degrees = value
		generate()

@export_group("Variation d'épaisseur")
## Épaisseur minimale/maximale que peut atteindre la branche principale (profondeur 0).
@export_range(1, 10, 1) var thickness_min: int = 1:
	set(value):
		thickness_min = min(value, thickness_max)
		generate()
@export_range(1, 10, 1) var thickness_max: int = 3:
	set(value):
		thickness_max = max(value, thickness_min)
		generate()
## Amplitude du changement d'épaisseur d'un segment à l'autre (0 = épaisseur figée).
@export_range(0.0, 2.0, 0.1) var thickness_variation_step: float = 0.4:
	set(value):
		thickness_variation_step = value
		generate()

@export_group("Branchements")
@export_range(0.0, 1.0, 0.01) var branch_chance: float = 0.1:
	set(value):
		branch_chance = value
		generate()
@export_range(0.05, 1.0, 0.01) var branch_chance_falloff: float = 0.35:
	set(value):
		branch_chance_falloff = value
		generate()
@export_range(0.1, 1.0, 0.05) var branch_length_ratio: float = 0.5:
	set(value):
		branch_length_ratio = value
		generate()
@export var branch_angle_spread_degrees: float = 45.0:
	set(value):
		branch_angle_spread_degrees = value
		generate()
@export_range(0, 6, 1) var max_branch_depth: int = 3:
	set(value):
		max_branch_depth = value
		generate()
@export_range(0, 3, 1) var thickness_falloff_per_depth: int = 1:
	set(value):
		thickness_falloff_per_depth = value
		generate()

@export_group("Apparence")
@export var crack_color: Color = Color(0, 0, 0, 1):
	set(value):
		crack_color = value
		self_modulate = crack_color

@export var rng_seed: int = 0:
	set(value):
		rng_seed = value
		generate()

@export_tool_button("Générer") var generate_btn: Callable = generate

var _rng := RandomNumberGenerator.new()
var _segments: Array = []
var _draw_surface: Node2D


func _ready() -> void:
	self_modulate = crack_color
	generate()


func _ensure_draw_surface() -> void:
	_draw_surface = get_node_or_null("DrawSurface")
	if _draw_surface == null:
		_draw_surface = Node2D.new()
		_draw_surface.name = "DrawSurface"
		_draw_surface.set_script(load("res://Scripts/MAP TOOLS/CrackDrawSurface.gd"))
		add_child(_draw_surface)
		if Engine.is_editor_hint():
			_draw_surface.owner = get_tree().edited_scene_root


func generate() -> void:
	if not is_inside_tree():
		return

	_ensure_draw_surface()

	_rng.seed = rng_seed
	_segments.clear()

	var start_dir := Vector2.RIGHT.rotated(deg_to_rad(start_angle_degrees))
	var start_grid := _to_grid(start_position)
	_walk(start_grid, start_dir, total_length, 0)

	print("CrackNetworkGenerator: %d segments générés" % _segments.size())
	_draw_surface.call("set_data", _segments, pixel_size)


func _walk(from_pos: Vector2i, initial_dir: Vector2, length: int, depth: int) -> void:
	var direction := initial_dir.normalized()
	var pos := Vector2(from_pos)
	var traveled: int = 0
	var current_branch_chance: float = branch_chance * pow(branch_chance_falloff, depth)

	var depth_scale: float = pow(1.0 - float(thickness_falloff_per_depth) / 10.0, depth)
	var local_min: float = max(thickness_min * depth_scale, 1.0)
	var local_max: float = max(thickness_max * depth_scale, local_min)

	var vary_thickness: bool = depth == 0
	var current_thickness: float
	if vary_thickness:
		current_thickness = _rng.randf_range(local_min, local_max)
	else:
		current_thickness = local_max  # épaisseur fixe pour les branches secondaires

	while traveled < length:
		var turn: float = _rng.randf_range(-max_turn_degrees, max_turn_degrees)
		direction = direction.rotated(deg_to_rad(turn))

		if vary_thickness:
			var thickness_delta: float = _rng.randf_range(-thickness_variation_step, thickness_variation_step)
			current_thickness = clamp(current_thickness + thickness_delta, local_min, local_max)

		var next_pos: Vector2 = pos + direction * segment_length
		var a := Vector2i(round(pos.x), round(pos.y))
		var b := Vector2i(round(next_pos.x), round(next_pos.y))
		var rounded_thickness: int = max(int(round(current_thickness)), 1)

		_segments.append({"a": a, "b": b, "thickness": rounded_thickness})

		pos = next_pos
		traveled += segment_length

		if depth < max_branch_depth and _rng.randf() < current_branch_chance:
			var remaining: int = length - traveled
			var branch_length: int = int(remaining * branch_length_ratio)
			if branch_length > segment_length * 2:
				var spread_rad: float = deg_to_rad(_rng.randf_range(-branch_angle_spread_degrees, branch_angle_spread_degrees))
				var branch_dir: Vector2 = direction.rotated(spread_rad)
				var branch_start := Vector2i(round(pos.x), round(pos.y))
				_walk(branch_start, branch_dir, branch_length, depth + 1)


func _to_grid(pos: Vector2) -> Vector2i:
	return Vector2i(round(pos.x / float(pixel_size)), round(pos.y / float(pixel_size)))
