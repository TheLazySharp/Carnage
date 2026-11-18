class_name RaidSpawnDirector
extends Node2D
## Builds the raid's spawners from a SpawnTable, before the map is generated.
## Each spawner is configured BEFORE add_child, so its own _ready() and its
## map_generated connection already see the balanced values.
## Static children (ColossArrival, ItemSpawner...) are left untouched.

## Set it in a scene that must ignore the biome (tutorial). Empty = biome table
@export var table_override : SpawnTable = null


func _ready() -> void:
	var table : SpawnTable = _get_table()
	if table == null:
		return
	# Direct launch (F6) or tutorial: no district played yet -> row 0
	var district : DistrictsData = RoadMapManager.last_district
	var row : int = district.row if district != null else 0
	var district_type : DistrictsData.types = district.type if district != null else DistrictsData.types.N_A
	var progress : float = clampf(float(row) / float(maxi(RoadMapManager.steps - 1, 1)), 0.0, 1.0)

	for entry : SpawnEntry in table.entries:
		if entry == null or not entry.is_active_for(row, district_type):
			continue
		var spawner : Node = entry.spawner_scene.instantiate()
		entry.configure(spawner, progress)
		add_child(spawner)


func _get_table() -> SpawnTable:
	if table_override != null:
		return table_override
	if BiomesManager.current_data == null or BiomesManager.current_data.spawn_table == null:
		push_warning("[RaidSpawnDirector] biome %s has no spawn_table: nothing spawned" % GameMaster.BIOMES.keys()[BiomesManager.current_biome])
		return null
	return BiomesManager.current_data.spawn_table
