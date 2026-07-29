@tool
extends EditorScript

# --- À adapter selon ton projet ---
const JSON_PATH := "res://Assets/Léonce/Props/Stencils/road_stencils.json"
const PNG_PATH := "res://Assets/Léonce/Props/Stencils/road_stencils.png"
const OUTPUT_DIR := "res://Assets/Léonce/Props/Stencils/"
# -----------------------------------

func _run() -> void:
	var dir := DirAccess.open("res://")
	if not dir.dir_exists(OUTPUT_DIR):
		dir.make_dir_recursive(OUTPUT_DIR)

	var file := FileAccess.open(JSON_PATH, FileAccess.READ)
	if file == null:
		push_error("Impossible d'ouvrir le JSON : %s" % JSON_PATH)
		return

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		push_error("Erreur de parsing JSON : %s" % json.get_error_message())
		return

	var data: Dictionary = json.data
	var meta: Dictionary = data.get("meta", {})
	var slices: Array = meta.get("slices", [])

	if slices.is_empty():
		push_warning("Aucun slice trouvé dans le JSON. Vérifie que l'export a bien été fait avec --list-slices.")
		return

	var count := 0
	for slice: Dictionary in slices:
		var slice_name: String = slice.get("name", "")
		var keys: Array = slice.get("keys", [])

		if slice_name == "" or keys.is_empty():
			push_warning("Slice ignoré (nom ou bounds manquant) : %s" % str(slice))
			continue

		var bounds: Dictionary = keys[0].get("bounds", {})

		var atlas_tex := AtlasTexture.new()
		atlas_tex.atlas = load(PNG_PATH)
		atlas_tex.region = Rect2(
			float(bounds.get("x", 0)),
			float(bounds.get("y", 0)),
			float(bounds.get("w", 0)),
			float(bounds.get("h", 0))
		)

		var save_path := OUTPUT_DIR + slice_name + ".tres"
		var err := ResourceSaver.save(atlas_tex, save_path)
		if err != OK:
			push_error("Échec de sauvegarde pour '%s' (code erreur %d)" % [slice_name, err])
		else:
			count += 1

	print("Terminé : %d AtlasTexture générées dans %s" % [count, OUTPUT_DIR])
