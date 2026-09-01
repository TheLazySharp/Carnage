@tool
extends Node2D
class_name BuildingShadow

@export var building_size: Vector2i = Vector2i(4, 3):
	set(value): building_size = value; queue_redraw()

@export var shadow_length: int = 6:
	set(value): shadow_length = value; queue_redraw()

@export var pixel_size: int = 4:
	set(value): pixel_size = value; queue_redraw()

@export var shadow_color: Color = Color(0, 0, 0, 1):
	set(value): shadow_color = value; queue_redraw()

func _draw() -> void:
	if not is_inside_tree():
		return

	var w := building_size.x * pixel_size
	var h := building_size.y * pixel_size
	var L := shadow_length * pixel_size

	var tl := Vector2(0, 0)
	var trail := Vector2(w, 0)
	var bl := Vector2(0, h)
	var trail_shifted := trail + Vector2(L, L)
	var bl_shifted := bl + Vector2(L, L)
	var br_shifted := Vector2(w, h) + Vector2(L, L)

	var poly := PackedVector2Array()
	poly.append(tl)
	poly.append(trail)
	poly.append_array(_staircase_edge(trail, trail_shifted, pixel_size, true))
	poly.append(br_shifted)
	poly.append(bl_shifted)
	poly.append_array(_staircase_edge(bl_shifted, bl, pixel_size, false))

	draw_colored_polygon(poly, shadow_color)


func _staircase_edge(from: Vector2, to: Vector2, step_size: int, horizontal_first: bool) -> PackedVector2Array:
	var points := PackedVector2Array()
	var dx_total: float = to.x - from.x
	var dy_total: float = to.y - from.y
	var steps: int = int(round(abs(dx_total) / step_size))
	var sx: float = step_size if dx_total > 0 else -step_size
	var sy: float = step_size if dy_total > 0 else -step_size

	var current := from
	for i in range(steps):
		if horizontal_first:
			current += Vector2(sx, 0)
			points.append(current)
			current += Vector2(0, sy)
			points.append(current)
		else:
			current += Vector2(0, sy)
			points.append(current)
			current += Vector2(sx, 0)
			points.append(current)
	return points
