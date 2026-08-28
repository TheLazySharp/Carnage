@tool
extends Node2D

var segments: Array = []
var pixel_size: int = 1


func set_data(new_segments: Array, new_pixel_size: int) -> void:
	segments = new_segments
	pixel_size = new_pixel_size
	queue_redraw()


func _draw() -> void:
	for seg: Dictionary in segments:
		var thick_points := get_thick_line_points(seg["a"], seg["b"], seg["thickness"])
		for p in thick_points:
			draw_rect(Rect2(Vector2(p) * pixel_size, Vector2(pixel_size, pixel_size)), Color.WHITE)


func get_thick_line_points(a: Vector2i, b: Vector2i, thick: int) -> Array[Vector2i]:
	var core_points := bresenham_line(a, b)
	if thick <= 1:
		return core_points
	var unique_points := {}
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
