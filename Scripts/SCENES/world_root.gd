extends Node2D
## World root. SceneManager calls build_level() behind the loading overlay.

var _built : bool = false
## Placeholder marking where the biome's Lands scene goes in the tree
@onready var lands_slot : Node2D = $LandsSlot

func _ready() -> void:
	_spawn_lands()
	# Direct launch (F6) has no SceneManager: build it ourselves if nobody did
	await get_tree().process_frame
	if not _built:
		await build_level()


func build_level() -> void:
	if _built:
		return
	_built = true
	var map_generator : Node = get_tree().get_first_node_in_group("map_generator")
	if map_generator == null:
		push_warning("[World] no node in the 'map_generator' group")
		return
	if not map_generator.has_method("generate_async"):
		push_warning("[World] the map_generator node has no generate_async()")
		return
	await map_generator.generate_async()
	_start_music()


func _start_music() -> void:
	SignalManager.emit_signal("start_background_music")

## The biome's Lands scene takes the slot's place in the tree, so the draw
## order and the World/Lands path stay what they were
func _spawn_lands() -> void:
	var path : String = BiomesManager.current_data.lands_scene_path if BiomesManager.current_data != null else ""
	if path.is_empty():
		push_error("[World] no Lands scene for biome %s" % GameMaster.BIOMES.keys()[BiomesManager.current_biome])
		return
	var packed : PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("[World] failed to load Lands scene: " + path)
		return
	var lands : Node2D = packed.instantiate() as Node2D
	lands.name = "Lands"
	lands.position = lands_slot.position
	lands_slot.add_sibling(lands)
	lands_slot.queue_free()
