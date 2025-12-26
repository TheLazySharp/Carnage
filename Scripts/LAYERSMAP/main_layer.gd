extends TileMapLayer

@onready var drop_layer: TileMapLayer = $"../Drop"

func _use_tile_data_runtime_update(coords):
	if coords in drop_layer.get_used_cells_by_id(8):
		return true
	return false

func _tile_data_runtime_update(coords, tile_data):
	if coords in drop_layer.get_used_cells_by_id(8):
		tile_data.set_navigation_polygon(0,null)


#func _update_cells(coords: Array[Vector2i], forced_cleanup: bool) -> void:
	#if coords in drop_layer.get_used_cells_by_id(8):
		#tile_data.set_navigation_polygon(0,null)
