@tool
extends Line2D
class_name PixelLine2D

@export var pixel_size: int = 4:
	set(value):
		pixel_size = value
		queue_redraw()

@export var pixel_color: Color = Color.WHITE:
	set(value):
		pixel_color = value
		queue_redraw()

@export var thickness: int = 1:
	set(value):
		thickness = value
		queue_redraw()

@export_group("Ombre du câble")
@export var draw_shadow: bool = false:
	set(value):
		draw_shadow = value
		queue_redraw()

@export var shadow_color: Color = Color(0, 0, 0, 0.35):
	set(value):
		shadow_color = value
		queue_redraw()

## Direction du soleil (doit matcher celle utilisée pour les ombres des bâtiments)
@export var shadow_direction: Vector2 = Vector2(1, 1):
	set(value):
		shadow_direction = value
		queue_redraw()

## Hauteur du câble au point le plus bas, en pixels virtuels
@export var shadow_sag: int = 6:
	set(value):
		shadow_sag = value
		queue_redraw()

## Position du point le plus bas le long du câble (0.5 = centré, <0.5 = plus tôt, >0.5 = plus tard)
@export_range(0.05, 0.95, 0.01) var shadow_sag_position: float = 0.5:
	set(value):
		shadow_sag_position = value
		queue_redraw()

## 1.0 = parabole classique. >1 = creux plus pointu (câble tendu). <1 = creux plus large/plat (câble lâche)
@export_range(0.2, 4.0, 0.05) var shadow_curve_shape: float = 1.0:
	set(value):
		shadow_curve_shape = value
		queue_redraw()

## Résolution d'échantillonnage de la courbe avant pixelisation. Diminue pour un rendu plus anguleux/géométrique.
@export_range(4, 64, 1) var shadow_samples: int = 24:
	set(value):
		shadow_samples = max(value, 2)
		queue_redraw()


func _ready() -> void:
	width = 0
	queue_redraw()


func _draw() -> void:
	if points.size() < 2:
		return

	if draw_shadow:
		_draw_cable_shadow()

	for i in range(points.size() - 1):
		var a := _to_grid(points[i])
		var b := _to_grid(points[i + 1])
		for p in get_thick_line_points(a, b, thickness):
			draw_rect(Rect2(Vector2(p) * pixel_size, Vector2(pixel_size, pixel_size)), pixel_color)


func _to_grid(pos: Vector2) -> Vector2i:
	return Vector2i(round(pos.x / float(pixel_size)), round(pos.y / float(pixel_size)))


func _draw_cable_shadow() -> void:
	for i in range(points.size() - 1):
		var a := _to_grid(points[i])
		var b := _to_grid(points[i + 1])
		for p in _get_cable_shadow_points(a, b):
			draw_rect(Rect2(Vector2(p) * pixel_size, Vector2(pixel_size, pixel_size)), shadow_color)


## Hauteur du câble au paramètre t (0..1) le long du segment, sous forme de parabole
## généralisée : nulle aux extrémités, maximale à shadow_sag_position, forme réglable
## via shadow_curve_shape.
func _sag_height(t: float) -> float:
	var peak := shadow_sag_position
	var denom := peak * (1.0 - peak)
	if denom <= 0.0:
		return 0.0
	var f: float = (t * (1.0 - t)) / denom
	f = clamp(f, 0.0, 1.0)
	return shadow_sag * pow(f, shadow_curve_shape)


func _get_cable_shadow_points(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var unique_points := {}
	var prev_point: Vector2i = a  # t=0, hauteur nulle, coïncide avec le câble

	for s in range(1, shadow_samples + 1):
		var t := float(s) / float(shadow_samples)
		var base: Vector2 = Vector2(a).lerp(Vector2(b), t)
		var h := _sag_height(t)
		var shifted: Vector2 = base + shadow_direction * h
		var grid_point := Vector2i(round(shifted.x), round(shifted.y))

		for p in get_thick_line_points(prev_point, grid_point, thickness):
			unique_points[p] = true
		prev_point = grid_point

	var result: Array[Vector2i] = []
	result.assign(unique_points.keys())
	return result


func get_thick_line_points(a: Vector2i, b: Vector2i, thick: int) -> Array[Vector2i]:
	var core_points := bresenham_line(a, b)
	if thick <= 1:
		return core_points

	var unique_points := {}
	@warning_ignore("integer_division")
	var half := thick / 2

	for p in core_points:
		for dx in range(-half, thick - half):
			for dy in range(-half, thick - half):
				unique_points[Vector2i(p.x + dx, p.y + dy)] = true

	var result: Array[Vector2i] = []
	result.assign(unique_points.keys())
	return result


func bresenham_line(p0: Vector2i, p1: Vector2i) -> Array[Vector2i]:
	var points_out: Array[Vector2i] = []
	var x0: int = p0.x
	var y0: int = p0.y
	var x1: int = p1.x
	var y1: int = p1.y
	var dx: int = abs(x1 - x0)
	var dy: int = -abs(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	while true:
		points_out.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return points_out
