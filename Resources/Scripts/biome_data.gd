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
## Roadmap random district types (root, survivor rows, shops and final are forced elsewhere)
@export var district_weights : Dictionary[DistrictsData.types, int] = {}
## Rows of this biome's roadmap, final district included (min RoadMapManager.MIN_STEPS)
@export var roadmap_steps : int = 10
## Every spawner of this biome's raids, with their progression along the roadmap
@export var spawn_table : SpawnTable

func validate() -> PackedStringArray:
	var issues : PackedStringArray = PackedStringArray()
	if map_config == null:
		issues.append("map_config is missing")
	if lands_scene_path.is_empty():
		issues.append("lands_scene_path is empty")
	var total_weight : int = 0
	for weight : int in district_weights.values():
		total_weight += weight
	if total_weight <= 0:
		issues.append("district_weights total is 0: the roadmap cannot pick a type")
	if roadmap_steps < RoadMapManager.MIN_STEPS:
		issues.append("roadmap_steps below %d: clamped" % RoadMapManager.MIN_STEPS)
	return issues
