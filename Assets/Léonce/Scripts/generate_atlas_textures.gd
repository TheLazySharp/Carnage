@tool
extends Node
class_name AtlasSlicer

## Glisse ici la texture PNG de l'atlas (depuis le panneau FileSystem)
@export var atlas_texture: Texture2D

## Glisse ici le .json exporté par Aseprite correspondant à cet atlas
@export_file("*.json") var json_path: String = ""

## Si laissé vide, les .tres sont générés dans le même dossier que atlas_texture
@export_dir var output_dir_override: String = ""

@export_tool_button("Extraire les textures") var extract_btn: Callable = extract


func extract() -> void:
	if atlas_texture == null:
		push_error("AtlasSlicer: assigne une atlas_texture avant de lancer l'extraction.")
		return
	if json_path.is_empty():
		push_error("AtlasSlicer: assigne un json_path avant de lancer l'extraction.")
		return
	if not FileAccess.file_exists(json_path):
		push_error("AtlasSlicer: fichier JSON introuvable : %s" % json_path)
		return

	var atlas_res_path := atlas_texture.resource_path
	if atlas_res_path.is_empty():
		push_error("AtlasSlicer: atlas_texture n'a pas de resource_path valide (texture non sauvegardée sur le disque ?).")
		return

	var output_dir := output_dir_override
	if output_dir.is_empty():
		output_dir = atlas_res_path.get_base_dir()

	var dir := DirAccess.open("res://")
	if not dir.dir_exists(output_dir):
		dir.make_dir_recursive(output_dir)

	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("AtlasSlicer: impossible d'ouvrir le JSON : %s" % json_path)
		return
	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		push_error("AtlasSlicer: erreur de parsing JSON : %s" % json.get_error_message())
		return

	var data: Dictionary = json.data
	var meta: Dictionary = data.get("meta", {})
	var slices: Array = meta.get("slices", [])
	if slices.is_empty():
		push_warning("AtlasSlicer: aucun slice trouvé dans le JSON. Vérifie que l'export Aseprite inclut bien les slices.")
		return

	var count := 0
	for slice: Dictionary in slices:
		var slice_name: String = slice.get("name", "")
		var keys: Array = slice.get("keys", [])
		if slice_name == "" or keys.is_empty():
			push_warning("AtlasSlicer: slice ignoré (nom ou bounds manquant) : %s" % str(slice))

		var bounds: Dictionary = keys[0].get("bounds", {})
		var atlas_tex := AtlasTexture.new()
		atlas_tex.atlas = atlas_texture
		atlas_tex.region = Rect2(
			float(bounds.get("x", 0)),
			float(bounds.get("y", 0)),
			float(bounds.get("w", 0)),
			float(bounds.get("h", 0))
		)

		var save_path := output_dir.path_join(slice_name + ".tres")
		var err := ResourceSaver.save(atlas_tex, save_path)
		if err != OK:
			push_error("AtlasSlicer: échec de sauvegarde pour '%s' (code erreur %d)" % [slice_name, err])
		else:
			count += 1

	print("AtlasSlicer: terminé — %d AtlasTexture générées dans %s" % [count, output_dir])
	if Engine.is_editor_hint():
		var fs := EditorInterface.get_resource_filesystem()
		fs.scan()
