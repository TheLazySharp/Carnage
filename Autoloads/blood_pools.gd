extends Node

@export_dir var main_folder: String = "res://Assets/VFX/BloodPools/BloodPoolMain/"
@export_dir var big_folder: String = "res://Assets/VFX/BloodPools/BloodPoolBig/"
@export_dir var small_folder: String = "res://Assets/VFX/BloodPools/BloodPoolSmall/"

var main_textures: Array[Texture2D] = []
var big_textures: Array[Texture2D] = []
var small_textures: Array[Texture2D] = []


func _ready() -> void:
	main_textures = _load_folder(main_folder)
	big_textures = _load_folder(big_folder)
	small_textures = _load_folder(small_folder)


func _load_folder(path: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		push_warning("BloodPools: dossier introuvable : %s" % path)
		return result
	var dir := DirAccess.open(path)
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "tres":
			var res := load(path.path_join(file_name))
			if res is Texture2D:
				result.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a: Texture2D, b: Texture2D) -> bool: return a.resource_path < b.resource_path)
	return result
