@tool
extends Node2D
class_name DrawSurface2D

## Chaque élément : {type: "rect", pos: Vector2, size: Vector2}
## ou {type: "polygon", points: PackedVector2Array}
## La couleur n'est pas stockée ici -- elle est pilotée par self_modulate
## du CanvasGroup parent, donc chaque item se dessine en blanc opaque.
var _items: Array = []


func set_items(items: Array) -> void:
	_items = items
	queue_redraw()


func _draw() -> void:
	for item: Dictionary in _items:
		match item["type"]:
			"rect":
				draw_rect(Rect2(item["pos"], item["size"]), Color.WHITE)
			"polygon":
				draw_colored_polygon(item["points"], Color.WHITE)
