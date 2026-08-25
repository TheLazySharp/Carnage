extends Node2D
## World root. SceneManager calls build_level() behind the loading overlay.

var _built : bool = false


func _ready() -> void:
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
