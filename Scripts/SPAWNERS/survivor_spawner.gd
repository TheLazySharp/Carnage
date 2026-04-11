extends Node2D

@export var new_survivor_scene : PackedScene
var survivor : SurvivorData
@export var tilemap : TileMapLayer
@export var nav_layer_index : int = 0 #BIT



func _ready() -> void:
	if !SurvivorsManager.unknown_survivors.is_empty():
		survivor = SurvivorsManager.unknown_survivors[0] #---------FOR NOW. WILL BE MODIFY TO ALLOW SEVERAL SURVIVOR TO SPAWN
		print(survivor.name," / ",survivor.job_ressource.job_title," / ",survivor.weapon.weapon_name)
		spawn_survivor()

func spawn_survivor() -> void : 
	var valid_positions : Array[Vector2] = get_valid_positions()
	
	if valid_positions.is_empty():
		push_warning("no valid position on ",tilemap)
		return
	
	valid_positions.shuffle()	
	spawn_at(valid_positions[0])


func get_valid_positions() -> Array[Vector2]:
	var positions : Array[Vector2] = []
	
	for cell : Vector2i in tilemap.get_used_cells():
		var tile_data: TileData = tilemap.get_cell_tile_data(cell)
		if tile_data == null :
			continue
		
		var nav_poly : NavigationPolygon = tile_data.get_navigation_polygon(nav_layer_index)
		if nav_poly != null:
			positions.append(tilemap.map_to_local(cell))
	
	return positions
	
func spawn_at(pos : Vector2) -> void : 
	var instance : Area2D = new_survivor_scene.instantiate()
	instance.position = pos
	instance.survivor = survivor
	add_child(instance)
	print("survivor spawned at : ",pos)
	pass
