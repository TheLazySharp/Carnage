extends Area2D


func spawn(spawn_position):
	global_position = spawn_position



func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player") or area.is_in_group("junior"):
		queue_free()
