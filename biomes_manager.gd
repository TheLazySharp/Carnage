extends Node
## Single owner of the run's biome state. Everything biome-dependent
## (roadmap weights, map generation, building pool, Lands scene) reads current_data.
## The biome only changes between two roadmaps, never during a raid.

## Run order, fixed for the demo
const BIOME_ORDER : Array[GameMaster.BIOMES] = [
	GameMaster.BIOMES.CITY,
	GameMaster.BIOMES.COUNTRYSIDE,
]

## Loaded on demand: a BiomeData drags its whole building pool into memory
var biomes_data_uid : Dictionary[GameMaster.BIOMES, String] = {
	GameMaster.BIOMES.CITY : "uid://REPLACE_CITY",
	GameMaster.BIOMES.COUNTRYSIDE : "uid://REPLACE_COUNTRYSIDE",
}

var biome_index : int = 0
var current_biome : GameMaster.BIOMES = GameMaster.BIOMES.CITY
var current_data : BiomeData = null
## True until the biome intro screen has been shown for current_biome
var intro_pending : bool = true


func _ready() -> void:
	_load_biome(BIOME_ORDER[0])


## Debug entry point (Lands scene run on its own): realigns the run index too
func set_biome(biome : GameMaster.BIOMES) -> void:
	var index : int = BIOME_ORDER.find(biome)
	if index != -1:
		biome_index = index
	_load_biome(biome)


## Next biome of the run. Returns false when the current biome was the last one.
func advance() -> bool:
	if is_last_biome():
		return false
	biome_index += 1
	_load_biome(BIOME_ORDER[biome_index])
	return true


func is_last_biome() -> bool:
	return biome_index >= BIOME_ORDER.size() - 1


func _load_biome(biome : GameMaster.BIOMES) -> void:
	if not biomes_data_uid.has(biome):
		push_error("[BiomesManager] no BiomeData for biome %s" % GameMaster.BIOMES.keys()[biome])
		return
	var data : BiomeData = load(biomes_data_uid[biome]) as BiomeData
	if data == null:
		push_error("[BiomesManager] failed to load BiomeData: " + biomes_data_uid[biome])
		return
	if OS.is_debug_build():
		for issue : String in data.validate():
			push_warning("[BiomesManager] %s: %s" % [GameMaster.BIOMES.keys()[biome], issue])
	current_biome = biome
	current_data = data
	intro_pending = true


func unload() -> void:
	biome_index = 0
	_load_biome(BIOME_ORDER[0])
