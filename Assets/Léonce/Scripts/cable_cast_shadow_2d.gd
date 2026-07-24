@tool
extends Node2D
class_name CableCastShadow2D

## Le PixelLine2D représentant le câble visible (peut être ailleurs dans l'arbre)
@export var cable_path: NodePath:
	set(value):
		cable_path = value
		_refresh_cable_ref()
		queue_redraw()

@export var shadow_sag: int = 6:
	set(value): shadow_sag = value; queue_redraw()

@export_range(0.05, 0.95, 0.01) var shadow_sag_position: float = 0.5:
	set(value): shadow_sag_position = value; queue_redraw()

@export_range(0.2, 4.0, 0.05) var shadow_curve_shape: float = 1.0:
	set(value): shadow_curve_shape = value; queue_redraw()

@export_range(4, 64, 1) var shadow_samples: int = 24:
	set(value): shadow_samples = max(value, 2); queue_redraw()

@export var shadow_direction: Vector2 = Vector2(1, 1):
	set(value): shadow_direction = value; queue_redraw()

## Alpha volontairement ignoré (garder 1.0) : la transparence finale
## est gérée une seule fois par le modulate du CanvasGroup parent.
@export var shadow_color: Color = Color(0, 0, 0, 1):
	set(value): shadow_color = value; queue_redraw()

var _cable: Line2D = null
var _last_points: PackedVector2Array = []

func _ready() -> void:
	_refresh_cable_ref()
	queue_redraw()

func _refresh_cable_ref() -> void:
	if not is_inside_tree() or cable_path.is_empty():
		_cable = null
		return
	var node := get_node_or_null(cable_path)
	_cable = node if node is Line2D else null

## En mode éditeur, on détecte les changements de points du câble pour
## se redessiner automatiquement (Line2D n'émet aucun signal sur `points`)
func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		return
	if _cable == null:
		return
	if _cable.points != _last_points:
		_last_points = _cable.points.duplicate()
		queue_redraw()

func _draw() -> void:
	if _cable == null or _cable.points.size() < 2:
		return

	var pixel_size: int = _cable.get("pixel_size") if _cable.get("pixel_size") != null else 4
	var thickness: int = _cable.get("thickness") if _cable.get("thickness") != null else 1

	for i in range(_cable.points.size() - 1):
		# Conversion : point local au câble -> global -> local à ce node
		var a_local := to_local(_cable.to_global(_cable.points[i]))
		var b_local := to_local(_cable.to_global(_cable.points[i + 1]))
		var a := _to_grid(a_local, pixel_size)
		var b := _to_grid(b_local, pixel_size)

		for p in _get_cable_shadow_points(a, b, pixel_size, thickness):
			draw_rect(Rect2(Vector2(p) * pixel_size, Vector2(pixel_size, pixel_size)), shadow_color)


func _to_grid(pos: Vector2, pixel_size: int) -> Vector2i:
	return Vector2i(round(pos.x / float(pixel_size)), round(pos.y / float(pixel_size)))


func _sag_height(t: float) -> float:
	var peak := shadow_sag_position
	var denom := peak * (1.0 - peak)
	if denom <= 0.0:
		return 0.0
	var f: float = clamp((t * (1.0 - t)) / denom, 0.0, 1.0)
	return shadow_sag * pow(f, shadow_curve_shape)


func _get_cable_shadow_points(a: Vector2i, b: Vector2i, pixel_size: int, thick: int) -> Array[Vector2i]:
	var unique_points := {}
	var prev_point: Vector2i = a

	for s in range(1, shadow_samples + 1):
		var t := float(s) / float(shadow_samples)
		var base: Vector2 = Vector2(a).lerp(Vector2(b), t)
		var shifted: Vector2 = base + shadow_direction * _sag_height(t)
		var grid_point := Vector2i(round(shifted.x), round(shifted.y))

		for p in get_thick_line_points(prev_point, grid_point, thick):
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
	var x0: int = p0.x; var y0: int = p0.y
	var x1: int = p1.x; var y1: int = p1.y
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
		if e2 >= dy: err += dy; x0 += sx
		if e2 <= dx: err += dx; y0 += sy
	return points_out
