extends Node2D


@onready var next_chunk_origin: Node2D = $NextChunkOrigin
var player : CarData

func _ready() -> void:
	player = CarManager.selected_car
	player.init_stats()

func _on_end_of_chunk_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		SignalManager.emit_signal("instantiate_new_chunk",next_chunk_origin.global_position)
