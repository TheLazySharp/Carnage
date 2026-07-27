extends Node

var all_buildings : Array[BuildingData] = []
var rng : RandomNumberGenerator = RandomNumberGenerator.new()

const ALL_BUILDINGS : Array = [
	preload("uid://c5gqwsyiy73ut"), #bank
]


func load_pools() -> void : 
	for building : BuildingData in ALL_BUILDINGS:
		all_buildings.append(building)

func pick_building(biome : GameMaster.BIOMES, district_type : DistrictsData.types) -> BuildingData:
	var candidates : Array[BuildingData] = []
	for building : BuildingData in all_buildings:
		if building.biome == biome and building.district_type == district_type:
			candidates.append(building)

	if candidates.is_empty():
		push_warning("BuildingsManager : aucun building pour biome=%s type=%s" % [biome, district_type])
		return null

	return candidates.pick_random()
