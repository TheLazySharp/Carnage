extends Node2D
class_name PixelTrail
## Traînée dessinée directement sur une grille de pixels (Image), qui
## s'adapte automatiquement à l'étendue réelle du trajet (pas de zone figée
## à définir à la main) — fonctionne aussi bien pour une orbite que pour un
## déplacement libre. Plusieurs streaks parallèles au sens du déplacement,
## avec une hiérarchie d'épaisseur/luminosité façon flamme (coeur fin et
## brillant, bords larges et sombres).

@export var target: NodePath
@export var trail_length := 40

@export_group("Grille")
@export var cell_size := 5.0      # taille d'une case, en unités-monde (règle la finesse du pixel)
@export var padding_cells := 2    # marge autour du trajet, en cases
@export var max_grid_size := 128  # sécurité anti-explosion mémoire (trajet très rapide/long, téléportation)

@export_group("Streaks")
@export var streak_count := 5      # nombre impair recommandé, pour un coeur centré
@export var streak_spacing := 4.0  # écart de base entre streaks, en unités-monde
@export var core_thickness := 1.0  # épaisseur (en cases) du streak central
@export var edge_thickness := 3.0  # épaisseur des streaks en bord
@export var core_brightness := 1.0 # alpha du streak central
@export var edge_brightness := 0.4 # alpha des streaks en bord
@export var color_pool: Array[Color] = []
@export var flicker_speed := 2.0
@export var streak_phase_step := 0.37

var _target_node: Node2D
var _points: PackedVector2Array = []
var _image: Image
var _texture: ImageTexture
var _sprite: Sprite2D
var _last_resolution := Vector2i(-1, -1)


func _ready() -> void:
	_image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)

	_sprite = Sprite2D.new()
	_sprite.texture = _texture
	_sprite.centered = true
	_sprite.top_level = true
	_sprite.visible = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sprite.material = mat
	add_child(_sprite)

	if target != NodePath():
		_target_node = get_node(target)


func _process(_delta: float) -> void:
	if _target_node:
		push_trail_point(_target_node.global_position)
	_redraw()


func push_trail_point(pos: Vector2) -> void:
	_points.append(pos)
	if _points.size() > trail_length:
		_points.remove_at(0)


## Hook reconnu par MousePointer.gd.
func preview_follow(pos: Vector2) -> void:
	push_trail_point(pos)


## Utile après une téléportation/un respawn, pour éviter un trait qui traverse tout l'écran.
func clear() -> void:
	_points.clear()


func _redraw() -> void:
	if _points.size() < 2:
		_sprite.visible = false
		return
	_sprite.visible = true

	# --- Bounding box du trajet actuel (+ marge pour les streaks et le padding) ---
	var min_x := _points[0].x
	var max_x := _points[0].x
	var min_y := _points[0].y
	var max_y := _points[0].y
	for p in _points:
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)

	var streak_extent: float = (float(streak_count - 1) / 2.0) * streak_spacing + edge_thickness * cell_size
	var pad: float = padding_cells * cell_size + streak_extent
	min_x -= pad
	max_x += pad
	min_y -= pad
	max_y += pad

	var origin := Vector2(min_x, min_y)
	var bbox_size := Vector2(max_x - min_x, max_y - min_y)

	var res_x: int = clampi(int(ceil(bbox_size.x / cell_size)) + 1, 1, max_grid_size)
	var res_y: int = clampi(int(ceil(bbox_size.y / cell_size)) + 1, 1, max_grid_size)
	var resolution := Vector2i(res_x, res_y)

	if resolution != _last_resolution:
		_image = Image.create(resolution.x, resolution.y, false, Image.FORMAT_RGBA8)
		_texture = ImageTexture.create_from_image(_image)
		_sprite.texture = _texture
		_last_resolution = resolution
	else:
		_image.fill(Color(0, 0, 0, 0))

	var now := Time.get_ticks_msec() / 1000.0
	var n := _points.size()
	var mid: float = float(streak_count - 1) / 2.0

	for i in range(1, n):
		var delta := _points[i] - _points[i - 1]
		if delta.length() < 0.001:
			continue
		var dir := delta.normalized()
		var perp := Vector2(-dir.y, dir.x)
		var t: float = float(i) / float(n - 1)  # 0 = queue, 1 = tête

		for s in range(streak_count):
			var d: float = abs(float(s) - mid) / max(mid, 0.001)  # 0 au centre, 1 sur les bords
			var thickness: float = lerp(core_thickness, edge_thickness, d)
			var brightness: float = lerp(core_brightness, edge_brightness, d)
			var lane_offset: float = (float(s) - mid) * streak_spacing

			var col := _streak_color(s, now)
			col.a *= t * brightness

			var half_thickness := thickness / 2.0
			var steps: int = max(int(ceil(thickness)), 1)
			for k in range(steps):
				var k_offset: float = -half_thickness + (float(k) + 0.5) * (thickness / float(steps))
				var world_pos := _points[i] + perp * (lane_offset + k_offset * cell_size)
				var rel := world_pos - origin
				var cell := Vector2i(int(rel.x / cell_size), int(rel.y / cell_size))
				if cell.x < 0 or cell.x >= resolution.x or cell.y < 0 or cell.y >= resolution.y:
					continue
				_image.set_pixelv(cell, col)

	_texture.update(_image)
	_sprite.scale = Vector2(cell_size, cell_size)
	_sprite.global_position = origin + bbox_size / 2.0


func _streak_color(streak_index: int, now: float) -> Color:
	if color_pool.is_empty():
		return Color.WHITE
	var n := color_pool.size()
	var phase: float = streak_index * streak_phase_step
	var time_bucket: float = floor(now * flicker_speed + phase * 10.0)
	var h := _hash(float(streak_index) * 13.17 + time_bucket * 7.31)
	var idx := int(h * float(n)) % n
	return color_pool[idx]


func _hash(n: float) -> float:
	var s := sin(n) * 43758.5453123
	return s - floor(s)
