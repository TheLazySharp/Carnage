extends Node2D
class_name TracerTrail2D

@export_group("Tir")
## Doit correspondre à la taille de pixel du reste de ton art.
@export var pixel_size: int = 1
## En pixels réels par seconde.
@export var projectile_speed: float = 1500.0
## Distance de vol du projectile, en pixels réels.
@export var max_range: float = 700.0

@export_group("Ligne")
## Épaisseur en pixels virtuels.
@export_range(1, 16, 1) var thickness: int = 3
## Durée de vie de chaque point de la ligne, en secondes.
@export_range(0.02, 5.0, 0.01) var trail_duration: float = 0.35
## Longueur maximale visible de la ligne derrière le projectile, en pixels réels.
## 0 = illimitée (seule la durée compte).
@export_range(0.0, 2000.0, 1.0, "or_greater") var trail_length: float = 0.0
## Couleur/alpha de la ligne selon l'âge du point (0 = frais, 1 = expiré).
## Astuce pixel art : interpolation du Gradient en "Constant" pour des paliers de palette.
@export var gradient: Gradient

@export_group("Double ligne (noyau plus opaque)")
@export var double_line: bool = false
@export_range(1, 16, 1) var core_thickness: int = 1
@export var core_gradient: Gradient

@export_group("Cycle de vie")
@export var free_when_finished: bool = true

class CellData:
	var cell: Vector2i
	var dist: float = 0.0
	var is_core: bool = false

var _cells: Array[CellData] = []
var _first_alive: int = 0
var _elapsed: float = 0.0
var _end_distance: float = 0.0
var _launched: bool = false


func _ready() -> void:
	_ensure_gradients()


## À appeler juste après l'instanciation (et l'ajout à l'arbre).
func launch(origin: Vector2, direction: Vector2) -> void:
	_ensure_gradients()
	top_level = true
	global_position = origin.snapped(Vector2(pixel_size, pixel_size))

	var dir: Vector2 = direction.normalized()
	var end_cell := Vector2i((dir * max_range / float(pixel_size)).round())
	_build_cells(_bresenham(Vector2i.ZERO, end_cell))

	_first_alive = 0
	_elapsed = 0.0
	_launched = true
	queue_redraw()


## Arrête la progression de la ligne à cette distance (en pixels depuis l'origine),
## par exemple quand le projectile touche quelque chose. La ligne finit de s'estomper normalement.
func stop_at(distance: float) -> void:
	var limit: float = minf(distance, _head_distance())
	var keep: int = _cells.size()
	for i: int in range(_first_alive, _cells.size()):
		if _cells[i].dist > limit:
			keep = i
			break
	_cells.resize(keep)
	_end_distance = limit


func _head_distance() -> float:
	return minf(projectile_speed * _elapsed, _end_distance)


## Distance en dessous de laquelle les points sont coupés (trail_length).
func _tail_distance() -> float:
	if trail_length <= 0.0:
		return -1.0
	return _head_distance() - trail_length


func _process(delta: float) -> void:
	if not _launched:
		return

	_elapsed += delta
	var speed: float = maxf(projectile_speed, 0.001)
	var duration: float = maxf(trail_duration, 0.001)
	var tail: float = _tail_distance()

	# Les cellules sont triées par distance : les plus vieilles expirent en premier.
	while _first_alive < _cells.size():
		var data: CellData = _cells[_first_alive]
		var age: float = _elapsed - data.dist / speed
		if age < duration and data.dist >= tail:
			break
		_first_alive += 1

	queue_redraw()

	if _first_alive >= _cells.size() and free_when_finished:
		queue_free()


func _draw() -> void:
	if not _launched:
		return

	var speed: float = maxf(projectile_speed, 0.001)
	var duration: float = maxf(trail_duration, 0.001)
	var head: float = _head_distance()
	var tail: float = _tail_distance()
	var cell_size := Vector2(pixel_size, pixel_size)

	for i: int in range(_first_alive, _cells.size()):
		var data: CellData = _cells[i]
		if data.dist > head:
			break
		if data.dist < tail:
			continue
		var age: float = _elapsed - data.dist / speed
		var t: float = clampf(age / duration, 0.0, 1.0)
		var g: Gradient = core_gradient if data.is_core else gradient
		draw_rect(Rect2(Vector2(data.cell) * pixel_size, cell_size), g.sample(t))


func _ensure_gradients() -> void:
	if gradient == null:
		gradient = _make_gradient(Color(1.0, 0.85, 0.4, 0.55), Color(1.0, 0.4, 0.1, 0.0))
	if core_gradient == null:
		core_gradient = _make_gradient(Color(1.0, 1.0, 0.9, 1.0), Color(1.0, 0.7, 0.3, 0.0))


func _make_gradient(start_color: Color, end_color: Color) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([start_color, end_color])
	return g


func _build_cells(line: Array[Vector2i]) -> void:
	var outer_map: Dictionary = {}
	var core_map: Dictionary = {}

	# La ligne est parcourue de l'origine vers la fin : la première insertion
	# d'une cellule correspond donc à sa distance minimale (sa date de naissance).
	for p: Vector2i in line:
		var dist: float = Vector2(p).length() * pixel_size
		_stamp(outer_map, p, thickness, dist)
		if double_line:
			_stamp(core_map, p, core_thickness, dist)

	var result: Array[CellData] = []

	for c: Vector2i in outer_map.keys():
		if core_map.has(c):
			continue
		var d := CellData.new()
		d.cell = c
		d.dist = outer_map[c]
		d.is_core = false
		result.append(d)

	for c: Vector2i in core_map.keys():
		var d := CellData.new()
		d.cell = c
		d.dist = core_map[c]
		d.is_core = true
		result.append(d)

	result.sort_custom(func(a: CellData, b: CellData) -> bool: return a.dist < b.dist)
	_cells = result

	if _cells.is_empty():
		_end_distance = 0.0
	else:
		_end_distance = _cells[_cells.size() - 1].dist


func _stamp(map: Dictionary, center: Vector2i, thick: int, dist: float) -> void:
	var lo: int = -int(thick * 0.5)
	var hi: int = thick + lo
	for dx: int in range(lo, hi):
		for dy: int in range(lo, hi):
			var c := Vector2i(center.x + dx, center.y + dy)
			if not map.has(c):
				map[c] = dist


func _bresenham(p0: Vector2i, p1: Vector2i) -> Array[Vector2i]:
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
