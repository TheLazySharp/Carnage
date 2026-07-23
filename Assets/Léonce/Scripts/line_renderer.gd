extends Line2D
class_name PixelLine2D

@export var pixel_size: int = 4
@export var pixel_color: Color = Color.WHITE

func _ready() -> void:
	# On coupe le rendu natif du Line2D, on ne garde que les données (points)
	width = 0
	queue_redraw()

func get_thick_line_points(a: Vector2i, b: Vector2i, thickness: int) -> Array[Vector2i]:
	var core_points := bresenham_line(a, b)
	if thickness <= 1:
		return core_points

	# On utilise un Dictionary comme "set" pour éviter les doublons
	# (plusieurs brush stamps se chevauchent le long de la ligne)
	var unique_points := {}
	var half := thickness / 2  # division entière

	for p in core_points:
		for dx in range(-half, thickness - half):
			for dy in range(-half, thickness - half):
				var stamped := Vector2i(p.x + dx, p.y + dy)
				unique_points[stamped] = true

	var result: Array[Vector2i] = []
	result.assign(unique_points.keys())
	return result
@export var thickness: int = 1

func _draw() -> void:
	if points.size() < 2:
		return
	for i in range(points.size() - 1):
		var a := Vector2i(round(points[i].x / float(pixel_size)), round(points[i].y / float(pixel_size)))
		var b := Vector2i(round(points[i + 1].x / float(pixel_size)), round(points[i + 1].y / float(pixel_size)))
		for p in get_thick_line_points(a, b, thickness):
			draw_rect(Rect2(Vector2(p) * pixel_size, Vector2(pixel_size, pixel_size)), pixel_color)

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
