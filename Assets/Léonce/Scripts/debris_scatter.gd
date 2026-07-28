@tool
extends Node2D
class_name DebrisScatter

## Dossier contenant les .tres générés par ton script de découpe (un par slice)
@export_dir var debris_textures_folder: String = "":
	set(value):
		debris_textures_folder = value
		_load_regions_from_folder()
		queue_redraw()

## Textures chargées automatiquement depuis debris_textures_folder
@export var debris_textures: Array[Texture2D] = []

## Taille de la zone de dispersion, en pixels virtuels (grille pixel art)
@export var bounds_size: Vector2i = Vector2i(64, 64):
	set(value):
		bounds_size = value
		queue_redraw()

@export var pixel_size: int = 4

## Nombre de débris à placer
@export_range(0, 500, 1) var item_count: int = 30

## Distance minimale entre deux débris, en pixels virtuels (0 = désactivé, autorise le chevauchement)
@export var min_distance: int = 3

@export var allow_flip: bool = true
@export var allow_rotation: bool = true

@export var rng_seed: int = 0

@export_tool_button("Recharger les .tres du dossier") var reload_folder_btn: Callable = _load_regions_from_folder
@export_tool_button("Générer") var generate_btn: Callable = generate
@export_tool_button("Effacer") var clear_btn: Callable = clear_debris


func _load_regions_from_folder() -> void:
	if debris_textures_folder.is_empty():
		return
	if not DirAccess.dir_exists_absolute(debris_textures_folder):
		push_warning("DebrisScatterArea2D: dossier introuvable : %s" % debris_textures_folder)
		return

	var dir := DirAccess.open(debris_textures_folder)
	if dir == null:
		push_warning("DebrisScatterArea2D: impossible d'ouvrir le dossier : %s" % debris_textures_folder)
		return

	var loaded: Array[Texture2D] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "tres":
			var res_path := debris_textures_folder.path_join(file_name)
			var res := load(res_path)
			if res is Texture2D:
				loaded.append(res)
			else:
				push_warning("DebrisScatterArea2D: %s n'est pas une Texture2D, ignoré." % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	# Tri alphabétique pour un ordre stable et reproductible entre deux rechargements
	loaded.sort_custom(func(a: Texture2D, b: Texture2D) -> bool: return a.resource_path < b.resource_path)

	debris_textures = loaded
	print("DebrisScatterArea2D: %d textures chargées depuis %s" % [loaded.size(), debris_textures_folder])


func generate() -> void:
	if not is_inside_tree():
		return
	if debris_textures.is_empty():
		push_warning("DebrisScatterArea2D: assigne debris_textures_folder et recharge, ou remplis debris_textures manuellement.")
		return

	clear_debris()

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var placed_positions: Array[Vector2] = []
	var max_attempts_per_item := 30
	var placed := 0
	var total_attempts := 0
	var max_total_attempts := item_count * max_attempts_per_item

	while placed < item_count and total_attempts < max_total_attempts:
		total_attempts += 1
		var gx := rng.randi_range(0, bounds_size.x - 1)
		var gy := rng.randi_range(0, bounds_size.y - 1)
		var candidate := Vector2(gx, gy) * pixel_size

		if min_distance > 0:
			var too_close := false
			var min_dist_px: float = min_distance * pixel_size
			for existing in placed_positions:
				if candidate.distance_to(existing) < min_dist_px:
					too_close = true
					break
			if too_close:
				continue

		_spawn_debris(candidate, rng)
		placed_positions.append(candidate)
		placed += 1

	if placed < item_count:
		push_warning("DebrisScatterArea2D: seulement %d/%d débris placés (zone trop dense pour min_distance)." % [placed, item_count])


func _spawn_debris(pos: Vector2, rng: RandomNumberGenerator) -> void:
	var tex: Texture2D = debris_textures[rng.randi_range(0, debris_textures.size() - 1)]

	var spr := Sprite2D.new()
	spr.texture = tex
	spr.position = pos
	spr.add_to_group("scatter_debris_generated")

	if allow_rotation:
		spr.rotation = rng.randi_range(0, 3) * (PI / 2.0)
	if allow_flip:
		spr.flip_h = rng.randi_range(0, 1) == 1
		spr.flip_v = rng.randi_range(0, 1) == 1

	add_child(spr)

	# Indispensable en mode @tool : sans owner, le node généré
	# n'est jamais sauvegardé dans la scène et disparaît à la réouverture.
	if Engine.is_editor_hint():
		spr.owner = get_tree().edited_scene_root


func clear_debris() -> void:
	for child in get_children():
		if child.is_in_group("scatter_debris_generated"):
			remove_child(child)
			child.free()


func _draw() -> void:
	if Engine.is_editor_hint():
		var rect_size := Vector2(bounds_size) * pixel_size
		draw_rect(Rect2(Vector2.ZERO, rect_size), Color(1, 1, 0, 0.5), false, 1.0)
