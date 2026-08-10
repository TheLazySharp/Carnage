@tool
extends Node2D
class_name SerpentineCrackGenerator

## Script à attacher automatiquement aux Path2D générés, pour qu'ils soient
## directement prêts à être rendus (stamps/détails à configurer ensuite).
@export var brush_script: Script

@export_group("Main path")
@export var start_position: Vector2 = Vector2.ZERO:
	set(value):
		start_position = value
		generate()
## Direction de départ, en degrés (0 = vers la droite).
@export_range(0.0, 360.0, 1.0) var start_angle_degrees: float = 0.0:
	set(value):
		start_angle_degrees = value
		generate()
@export var total_length: float = 300.0:
	set(value):
		total_length = max(value, 1.0)
		generate()
## Distance entre deux points ajoutés à la courbe. Plus petit = plus de détail
## dans les sinuosités, mais plus de points au total.
@export var segment_length: float = 8.0:
	set(value):
		segment_length = max(value, 1.0)
		generate()
## Variation maximale d'angle à chaque pas, en degrés.
@export_range(0.0, 45.0, 0.5) var max_turn_degrees: float = 12.0:
	set(value):
		max_turn_degrees = value
		generate()
## Lisse les changements de direction d'un pas à l'autre (0 = zigzag brut,
## proche de 1 = virages très progressifs, façon inertie).
@export_range(0.0, 0.95, 0.01) var turn_smoothing: float = 0.5:
	set(value):
		turn_smoothing = value
		generate()

@export_group("Branching")
## Probabilité de créer une branche à chaque pas.
@export_range(0.0, 0.1, 0.01) var branch_chance: float = 0.02:
	set(value):
		branch_chance = value
		generate()
## Longueur d'une branche, en proportion de la longueur restante du tracé parent.
@export_range(0.1, 1.0, 0.05) var branch_length_ratio: float = 0.5:
	set(value):
		branch_length_ratio = value
		generate()
## Écart d'angle d'une branche par rapport à la direction du tracé parent, en degrés.
@export var branch_angle_spread_degrees: float = 40.0:
	set(value):
		branch_angle_spread_degrees = value
		generate()
## Profondeur maximale de branchement (0 = uniquement le tracé principal, pas de branches).
@export_range(0, 5, 1) var max_branch_depth: int = 2:
	set(value):
		max_branch_depth = value
		generate()

@export var rng_seed: int = 0:
	set(value):
		rng_seed = value
		generate()
		
@export_group("Stamps")
		
@export_dir var default_stamp_folder: String = "":
	set(value):
		default_stamp_folder = value
		generate()
@export_dir var default_detail_folder: String = "":
	set(value):
		default_detail_folder = value
		generate()
@export var default_stamp_color: Color = Color.WHITE:
	set(value):
		default_stamp_color = value
		generate()
@export var default_detail_color: Color = Color.WHITE:
	set(value):
		default_detail_color = value
		generate()
@export var default_pixel_size: int = 4:
	set(value):
		default_pixel_size = value
		generate()
@export var default_stamp_spacing: int = 2:
	set(value):
		default_stamp_spacing = max(value, 1)
		generate()

@export_tool_button("Generate") var generate_btn: Callable = generate

var _rng := RandomNumberGenerator.new()
var _branch_counter: int = 0


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


## Génère un tracé (marche aléatoire) à partir d'une position/direction donnée,
## crée le Path2D correspondant, et déclenche récursivement des branches en cours de route.
func _walk(from_pos: Vector2, initial_dir: Vector2, length: float, depth: int, node_name: String) -> void:
	var path := Path2D.new()
	path.name = node_name
	add_child(path)
	if Engine.is_editor_hint():
		path.owner = get_tree().edited_scene_root

	if brush_script != null:
		path.set_script(brush_script)
		_apply_default_brush_settings(path)

	var curve := Curve2D.new()
	path.curve = curve
	path.position = from_pos

	var direction := initial_dir.normalized()
	var pos := Vector2.ZERO
	var traveled: float = 0.0

	curve.add_point(pos)

	while traveled < length:
		var turn: float = _rng.randf_range(-max_turn_degrees, max_turn_degrees)
		var turn_rad: float = deg_to_rad(turn) * (1.0 - turn_smoothing)
		direction = direction.rotated(turn_rad)

		pos += direction * segment_length
		traveled += segment_length
		curve.add_point(pos)

		if depth < max_branch_depth and _rng.randf() < branch_chance:
			var remaining: float = length - traveled
			var branch_length: float = remaining * branch_length_ratio
			if branch_length > segment_length * 2.0:
				var spread_rad: float = deg_to_rad(_rng.randf_range(-branch_angle_spread_degrees, branch_angle_spread_degrees))
				var branch_dir: Vector2 = direction.rotated(spread_rad)
				var branch_world_pos: Vector2 = from_pos + pos
				_branch_counter += 1
				_walk(branch_world_pos, branch_dir, branch_length, depth + 1, "Crack_Branch_%d" % _branch_counter)

	# curve.changed s'est déjà déclenché plusieurs fois pendant la construction
	# (à chaque add_point) -- on force une régénération finale propre une fois
	# le tracé complet et les réglages par défaut en place.
	if path.has_method("generate_all"):
		path.call("generate_all")


func _apply_default_brush_settings(path: Node) -> void:
	if not default_stamp_folder.is_empty():
		path.set("stamp_folder", default_stamp_folder)
	if not default_detail_folder.is_empty():
		path.set("detail_folder", default_detail_folder)
	path.set("stamp_color", default_stamp_color)
	path.set("detail_color", default_detail_color)
	path.set("pixel_size", default_pixel_size)
	path.set("stamp_spacing", default_stamp_spacing)
