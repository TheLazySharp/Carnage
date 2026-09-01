@tool
extends Node2D
class_name SerpentineCrackGenerator
## Crack drawn with the project's brush tool: one Path2D per branch, each
## carrying `brush_script` (RoadBrushPath2D) which does the stamping.
##
## Property names match CrackNetworkGenerator wherever they mean the same thing
## (pixel_size, crack_color, total_length, branch_*), so MapRoadCracks drives
## both generators through one code path.
##
## UNITS: total_length and segment_length are in PIXELS here, not in grid steps.

## RoadBrushPath2D script, attached to every generated Path2D
@export var brush_script: Script

@export_group("Main path")
@export var start_position: Vector2 = Vector2.ZERO:
	set(value):
		start_position = value
		generate()
## Starting direction, in degrees (0 = to the right)
@export_range(0.0, 360.0, 1.0) var start_angle_degrees: float = 0.0:
	set(value):
		start_angle_degrees = value
		generate()
@export var total_length: float = 300.0:
	set(value):
		total_length = max(value, 1.0)
		generate()
@export var segment_length: float = 8.0:
	set(value):
		segment_length = max(value, 1.0)
		generate()
@export_range(0.0, 45.0, 0.5) var max_turn_degrees: float = 12.0:
	set(value):
		max_turn_degrees = value
		generate()
## Smooths direction changes (0 = raw zigzag, near 1 = long lazy curves)
@export_range(0.0, 0.95, 0.01) var turn_smoothing: float = 0.5:
	set(value):
		turn_smoothing = value
		generate()

@export_group("Branching")
## Range widened to 1.0: the pass rolls it from the profile
@export_range(0.0, 1.0, 0.01) var branch_chance: float = 0.02:
	set(value):
		branch_chance = value
		generate()
## Branch chance multiplier per depth level
@export_range(0.05, 1.0, 0.01) var branch_chance_falloff: float = 0.35:
	set(value):
		branch_chance_falloff = value
		generate()
@export_range(0.1, 1.0, 0.05) var branch_length_ratio: float = 0.5:
	set(value):
		branch_length_ratio = value
		generate()
@export var branch_angle_spread_degrees: float = 40.0:
	set(value):
		branch_angle_spread_degrees = value
		generate()
@export_range(0, 5, 1) var max_branch_depth: int = 2:
	set(value):
		max_branch_depth = value
		generate()

@export_group("Appearance")
## Same name as CrackNetworkGenerator: modulate is what the pulse tween drives.
@export var crack_color: Color = Color(0, 0, 0, 1):
	set(value):
		crack_color = value
		modulate = crack_color
@export var pixel_size: int = 4:
	set(value):
		pixel_size = max(value, 1)
		generate()
@export var stamp_spacing_min: int = 2:
	set(value):
		stamp_spacing_min = max(value, 1)
		generate()
@export var stamp_spacing_max: int = 4:
	set(value):
		stamp_spacing_max = max(value, stamp_spacing_min)
		generate()
## Inspector-filled, NEVER scanned from a folder: a runtime DirAccess scan
## returns unusable names inside an exported PCK.
@export var stamp_textures: Array[Texture2D] = []:
	set(value):
		stamp_textures = value
		generate()
@export var detail_textures: Array[Texture2D] = []:
	set(value):
		detail_textures = value
		generate()

@export var rng_seed: int = 0:
	set(value):
		rng_seed = value
		generate()

@export_tool_button("Generate") var generate_btn: Callable = generate

var _rng := RandomNumberGenerator.new()
var _branch_counter: int = 0


func _ready() -> void:
	modulate = crack_color
	generate()


func generate() -> void:
	if not is_inside_tree():
		return
	_clear_previous()
	_rng.seed = rng_seed
	_branch_counter = 0
	var start_dir := Vector2.RIGHT.rotated(deg_to_rad(start_angle_degrees))
	_walk(start_position, start_dir, total_length, 0, "Crack_Root")


func _clear_previous() -> void:
	for child in get_children():
		if child.name.begins_with("Crack_"):
			remove_child(child)
			child.free()


func _walk(from_pos: Vector2, initial_dir: Vector2, length: float, depth: int, node_name: String) -> void:
	var path := Path2D.new()
	path.name = node_name
	path.position = from_pos
	if brush_script != null:
		path.set_script(brush_script)
		_apply_brush_settings(path)

	var curve := Curve2D.new()
	var direction := initial_dir.normalized()
	var pos := Vector2.ZERO
	var traveled: float = 0.0
	curve.add_point(pos)

	# Branches are collected, not walked inline: the parent path must be fully
	# built and added first, otherwise the brush regenerates on every point.
	var branches: Array[Array] = []
	var chance: float = branch_chance * pow(branch_chance_falloff, depth)

	while traveled < length:
		var turn_rad: float = deg_to_rad(_rng.randf_range(-max_turn_degrees, max_turn_degrees)) * (1.0 - turn_smoothing)
		direction = direction.rotated(turn_rad)
		pos += direction * segment_length
		traveled += segment_length
		curve.add_point(pos)
		if depth < max_branch_depth and _rng.randf() < chance:
			var remaining: float = length - traveled
			var branch_length: float = remaining * branch_length_ratio
			if branch_length > segment_length * 2.0:
				var spread_rad: float = deg_to_rad(_rng.randf_range(-branch_angle_spread_degrees, branch_angle_spread_degrees))
				branches.append([from_pos + pos, direction.rotated(spread_rad), branch_length])

	# Curve assigned BEFORE add_child, so the brush's _ready sees the finished
	# path and stamps it exactly once.
	path.curve = curve
	add_child(path)
	if Engine.is_editor_hint():
		path.owner = get_tree().edited_scene_root

	for branch: Array in branches:
		_branch_counter += 1
		_walk(branch[0], branch[1], branch[2], depth + 1, "Crack_Branch_%d" % _branch_counter)


func _apply_brush_settings(path: Node) -> void:
	# RoadBrushPath2D property names. stamp_spacing_max first: the two setters
	# clamp against each other and writing min first would lower it.
	path.set("_stamp_textures", stamp_textures)
	path.set("_detail_textures", detail_textures)
	path.set("pixel_size", pixel_size)
	path.set("stamp_spacing_max", stamp_spacing_max)
	path.set("stamp_spacing_min", stamp_spacing_min)
