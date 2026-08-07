extends CanvasGroup
class_name BloodSplatter

@export_group("Quantity")
@export_range(1, 10, 1) var big_count_min: int = 1
@export_range(1, 10, 1) var big_count_max: int = 3
@export_range(1, 30, 1) var small_count_min: int = 3
@export_range(1, 30, 1) var small_count_max: int = 6

@export_group("Placement")
@export_range(1, 16, 1) var pixel_size: int = 1
@export_range(0, 128, 1) var big_scatter_radius: int = 8
@export_range(0, 256, 1) var small_scatter_radius: int = 14
@export_range(0, 64, 1) var min_distance: int = 3
@export var big_scatter_offset: int = -4
@export var small_scatter_offset: int = -8

@export_group("Rotation")
@export var constrain_rotation_90: bool = false
@export var allow_flip: bool = true

@export_group("Timing")
@export_range(0.0, 3.0, 0.01) var spawn_duration: float = 0.25

@export_group("Colors")
@export var fresh_color: Color = Color.WHITE:
	set(value):
		fresh_color = value
		self_modulate = fresh_color   # aperçu dans l'éditeur
## Teinte du sang mort, non récoltable.
@export var rotten_color: Color = Color(0.35, 0.12, 0.12)

var play_generation: int = 0

## aged_ratio : 0.0 = fresh 1.0 = rotten.

func set_freshness(aged_ratio: float) -> void:
	self_modulate = fresh_color.lerp(rotten_color, aged_ratio)

func set_rotten() -> void:
	self_modulate = rotten_color


## Désactive pour réutiliser l'effet sans la tache d'impact principale
## (par exemple pour des éclaboussures secondaires dans un autre contexte).
@export var spawn_main_splat: bool = true

var _rng := RandomNumberGenerator.new()
var _placed_positions: Array[Vector2] = []

func _ready() -> void:
	_rng.randomize()
	self_modulate = fresh_color


func face_direction(direction: Vector2) -> void:
	if direction.length_squared() > 0.0:
		rotation = direction.angle()


## Méthode publique à appeler depuis une piste "Call Method" de l'AnimationPlayer,
## ou directement depuis le script qui gère les dégâts/la mort de l'ennemi.
func play() -> void:
	play_generation += 1
	clear_splats()
	_spawn_sequence(play_generation)


class PendingSplat:
	var texture: Texture2D
	var position: Vector2
	var is_main: bool = false


func _spawn_sequence(generation: int) -> void:
	var pending: Array[PendingSplat] = []

	if spawn_main_splat and not BloodPools.main_textures.is_empty():
		var main_tex: Texture2D = BloodPools.main_textures[_rng.randi_range(0, BloodPools.main_textures.size() - 1)]
		pending.append(_make_pending(main_tex, Vector2.ZERO, true))
	elif spawn_main_splat:
		push_warning("BloodSplatter: aucune texture dans BloodPools.main_textures.")

	if not BloodPools.big_textures.is_empty():
		var big_center := Vector2(big_scatter_offset, 0) * pixel_size
		var big_count := _rng.randi_range(big_count_min, big_count_max)
		for i in range(big_count):
			var pos := big_center + _find_scatter_position(big_scatter_radius)
			var tex: Texture2D = BloodPools.big_textures[_rng.randi_range(0, BloodPools.big_textures.size() - 1)]
			pending.append(_make_pending(tex, pos, false))

	if not BloodPools.small_textures.is_empty():
		var small_center := Vector2(small_scatter_offset, 0) * pixel_size
		var small_count := _rng.randi_range(small_count_min, small_count_max)
		for i in range(small_count):
			var pos := small_center + _find_scatter_position(small_scatter_radius)
			var tex: Texture2D = BloodPools.small_textures[_rng.randi_range(0, BloodPools.small_textures.size() - 1)]
			pending.append(_make_pending(tex, pos, false))

	pending.sort_custom(func(a: PendingSplat, b: PendingSplat) -> bool: return a.position.x > b.position.x)

	if pending.is_empty():
		return

	var delay_between: float = spawn_duration / float(pending.size())
	for splat in pending:
		if generation != play_generation:
			return
		_instantiate_splat(splat)
		if delay_between > 0.0:
			await get_tree().create_timer(delay_between).timeout


func _make_pending(tex: Texture2D, pos: Vector2, is_main: bool) -> PendingSplat:
	var p := PendingSplat.new()
	p.texture = tex
	p.position = pos
	p.is_main = is_main
	_placed_positions.append(pos)
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

	if splat.is_main:
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

func clear_splats() -> void:
	for child in get_children():
		child.free()
	_placed_positions.clear()
