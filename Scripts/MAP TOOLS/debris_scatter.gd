@tool
extends Node2D
class_name DebrisScatter

@export var debris_textures: Array[Texture2D] = []


@export_group("Density")
## Debris per 1000 virtual pixels of area. The count is derived from the patch
## area, then clamped: a small patch never gets 50 items, a large one never 10.
@export var density_per_1000: float = 60.0
@export var item_count_min: int = 10
@export var item_count_max: int = 50

## Taille de la zone de dispersion, en pixels virtuels (grille pixel art)
@export var bounds_size: Vector2i = Vector2i(64, 64):
	set(value):
		bounds_size = value
		queue_redraw()

@export var pixel_size: int = 4


## Distance minimale entre deux débris, en pixels virtuels (0 = désactivé, autorise le chevauchement)
@export var min_distance: int = 3

@export var allow_flip: bool = true
@export var allow_rotation: bool = true

@export var rng_seed: int = 0

@export_tool_button("Générer") var generate_btn: Callable = generate
@export_tool_button("Effacer") var clear_btn: Callable = clear_debris


func generate() -> void:
	if not is_inside_tree():
		return
	if debris_textures.is_empty():
		push_warning("DebrisScatter: debris_textures is empty, fill it in the inspector.")
		return
	clear_debris()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	# Area-driven count, with a random band so two patches of the same size do
	# not end up with the same density.
	var area: float = float(bounds_size.x * bounds_size.y)
	var base: int = int(round(area / 1000.0 * density_per_1000))
	var high: int = clampi(base, item_count_min, item_count_max)
	var low: int = clampi(int(round(float(base) * 0.6)), item_count_min, high)
	var item_count: int = rng.randi_range(low, high)

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
