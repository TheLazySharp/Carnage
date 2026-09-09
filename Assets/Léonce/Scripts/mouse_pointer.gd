extends Node2D
class_name MousePointer


@export var followers: Array[Node2D] = []
@export var show_cursor_marker := true

func _process(_delta: float) -> void:
	var pos := get_global_mouse_position()
	global_position = pos

	for follower in followers:
		if follower == null:
			continue
		if follower.has_method("preview_follow"):
			follower.preview_follow(pos)
		else:
			follower.global_position = pos

	if show_cursor_marker:
		queue_redraw()

func _draw() -> void:
	if show_cursor_marker:
		draw_circle(Vector2.ZERO, 3.0, Color(1, 1, 1, 0.6))
