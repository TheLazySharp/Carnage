extends Node2D

@export var ressource_scene : PackedScene
@export var nb_ressource : int = 100
@export var tilemap : TileMapLayer
@export var nav_layer_index : int = 0 #BIT



func _ready() -> void:
	#spawn_ressources()
	pass


func spawn_ressources() -> void : 
	var valid_positions : Array[Vector2] = get_valid_positions()
	
	if valid_positions.is_empty():
		push_warning("no valid position on ",tilemap)
		return
	
	valid_positions.shuffle()
	var count : int = mini(nb_ressource, valid_positions.size())
	
	for i : int in range(count):
		spawn_at(valid_positions[i])


func get_valid_positions() -> Array[Vector2]:
	var positions : Array[Vector2] = []
	
	for cell : Vector2i in tilemap.get_used_cells():
		var tile_data: TileData = tilemap.get_cell_tile_data(cell)
		if tile_data == null :
			print("tile empty")
			continue
		
		var nav_poly : NavigationPolygon = tile_data.get_navigation_polygon(nav_layer_index)
		if nav_poly != null:
			positions.append(tilemap.map_to_local(cell))
	
	return positions
	
func spawn_at(pos : Vector2) -> void : 
	var instance : Area2D = ressource_scene.instantiate()
	instance.position = pos
	add_child(instance)
