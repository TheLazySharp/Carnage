extends Node2D


func _on_end_of_chunk_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		SignalManager.emit_signal("end_autopilot_transition")
		


func _on_start_autopilot_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		SignalManager.emit_signal("start_autopilot_transition")
