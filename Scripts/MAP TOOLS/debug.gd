extends Node
## Diagnostic tool for the graph -> Path2D bridge.
## Attach to any node of the test scene and press D while playing:
## dumps every Path2D of the scene (curve points, transform, visibility)
## and, for RoadBrushPath2D instances, how many textures actually load
## from their folders and how many sprites their layers hold.

func _unhandled_input(event : InputEvent) -> void:
	var key : InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_D:
		dump()


func dump() -> void:
	var paths : Array[Node] = []
	_collect(get_tree().current_scene, paths)
	print("\n========== PATH2D DUMP : ", paths.size(), " Path2D found ==========")
	if paths.is_empty():
		print("  No Path2D in the scene -> MapRoadPaths.build() never instantiated anything.")
		print("  Check: the debug node's road_paths field, and MapRoadPaths.street_template.")
	for node : Node in paths:
		_dump_path(node as Path2D)
	print("========== END DUMP ==========\n")


func _collect(node : Node, out : Array[Node]) -> void:
	if node is Path2D:
		out.append(node)
	for child : Node in node.get_children():
		_collect(child, out)


func _dump_path(path : Path2D) -> void:
	print("--- ", path.get_path())
	print("  script        : ", path.get_script().resource_path if path.get_script() != null else "<none>")
	print("  global_pos    : ", path.global_position, "  scale: ", path.global_scale)
	print("  visible       : ", path.visible, "  visible_in_tree: ", path.is_visible_in_tree())
	print("  z_index       : ", path.z_index, "  z_as_relative: ", path.z_as_relative, "  modulate: ", path.modulate)

	if path.curve == null:
		print("  curve         : NULL  <-- nothing to draw along")
	else:
		var count : int = path.curve.get_point_count()
		print("  curve points  : ", count, "  baked_length: ", path.curve.get_baked_length())
		for i : int in count:
			var local : Vector2 = path.curve.get_point_position(i)
			print("     [", i, "] local ", local, "  global ", path.to_global(local))

	# RoadBrushPath2D specifics: do the folders actually yield textures?
	var stamp_folder : Variant = path.get("stamp_folder")
	if stamp_folder != null:
		print("  pixel_size    : ", path.get("pixel_size"), "  stamp_spacing: ", path.get("stamp_spacing"))
		print("  stamp_folder  : '", stamp_folder, "' -> ", _count_textures(stamp_folder), " textures loaded")
		var detail_folder : Variant = path.get("detail_folder")
		if detail_folder != null:
			print("  detail_folder : '", detail_folder, "' -> ", _count_textures(detail_folder), " textures loaded")

	for child : Node in path.get_children():
		var item : CanvasItem = child as CanvasItem
		var extra : String = ""
		if item != null:
			extra = "  visible: %s  z: %d  modulate: %s" % [item.visible, item.z_index, item.self_modulate]
		print("  child ", child.name, " (", child.get_class(), ") : ", child.get_child_count(), " children", extra)


func _count_textures(folder : String) -> int:
	# Mirrors RoadBrushPath2D._load_folder: only .tres files are picked up
	if folder.is_empty() or not DirAccess.dir_exists_absolute(folder):
		print("     WARNING: folder missing or empty path")
		return 0
	var found : int = 0
	var other_files : int = 0
	var dir : DirAccess = DirAccess.open(folder)
	dir.list_dir_begin()
	var file_name : String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			if file_name.get_extension() == "tres":
				var res : Resource = load(folder.path_join(file_name))
				if res is Texture2D:
					found += 1
			elif file_name.get_extension() != "import":
				other_files += 1
		file_name = dir.get_next()
	dir.list_dir_end()
	if other_files > 0:
		print("     note: ", other_files, " non-.tres files ignored by _load_folder")
	return found
