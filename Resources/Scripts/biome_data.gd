class_name BiomeData
extends Resource
## Everything generation and the roadmap need to know about one biome.
## Rendering resources (tilesets, brushes, props) live in the biome's Lands scene.

@export var biome : GameMaster.BIOMES = GameMaster.BIOMES.CITY
## Translation key shown by the biome intro screen
@export var display_name_key : String = ""
## Lands scene of this biome, loaded on demand by World
@export_file("*.tscn") var lands_scene_path : String = ""
@export var map_config : MapGenConfig
@export var building_pool : BuildingPool
## Roadmap random district types (root, survivor rows, shops and final are forced elsewhere)
@export var district_weights : Dictionary[DistrictsData.types, int] = {}


func validate() -> PackedStringArray:
	var issues : PackedStringArray = PackedStringArray()
	if map_config == null:
		issues.append("map_config is missing")
	if building_pool == null:
		issues.append("building_pool is missing")
	elif building_pool.biome != biome:
		issues.append("building_pool belongs to another biome")
	if lands_scene_path.is_empty():
		issues.append("lands_scene_path is empty")
	var total_weight : int = 0
	for weight : int in district_weights.values():
		total_weight += weight
	if total_weight <= 0:
		issues.append("district_weights total is 0: the roadmap cannot pick a type")
	return issues
