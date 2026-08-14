@tool
extends EditorScript

# Atlas slicer : cuts a sprite sheet into individual .png files.
# Usage : open this file in the Godot script editor, then File > Run (Ctrl+Shift+X).

# ---- CONFIG ----
const ATLAS_PATH : String = "res://Assets/Items/Drops/Dollars/bills_bigger.png"
const OUTPUT_DIR : String = "res://Assets/Items/Drops/Dollars/"
const PREFIX : String = "dollar_"
const FRAME_SIZE : Vector2i = Vector2i(9, 9)
const SPACING : Vector2i = Vector2i.ZERO	# gap between frames
const MARGIN : Vector2i = Vector2i.ZERO		# offset before the first frame
const SKIP_EMPTY : bool = true				# do not export fully transparent frames
const ROW_IN_NAME : bool = false			# true -> prefix_r0_c2.png, false -> prefix_0.png


func _run() -> void:
	var abs_atlas : String = ProjectSettings.globalize_path(ATLAS_PATH)
	var image : Image = Image.load_from_file(abs_atlas)
	if image == null:
		push_error("Atlas not found : %s" % ATLAS_PATH)
		return

	var abs_out : String = ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(abs_out)

	var atlas_size : Vector2i = image.get_size()
	var step : Vector2i = FRAME_SIZE + SPACING
	var cols : int = (atlas_size.x - MARGIN.x + SPACING.x) / step.x
	var rows : int = (atlas_size.y - MARGIN.y + SPACING.y) / step.y

	if cols <= 0 or rows <= 0:
		push_error("Frame size bigger than the atlas (%s)" % atlas_size)
		return

	# Warn when the atlas is not an exact multiple of the frame size
	var used : Vector2i = Vector2i(MARGIN.x + cols * step.x - SPACING.x, MARGIN.y + rows * step.y - SPACING.y)
	if used != atlas_size:
		push_warning("Atlas %s : %d x %d frames used, %s px left over" % [atlas_size, cols, rows, atlas_size - used])

	var index : int = 0
	var exported : int = 0
	for y : int in rows:
		for x : int in cols:
			var region : Rect2i = Rect2i(MARGIN + Vector2i(x, y) * step, FRAME_SIZE)
			var frame : Image = image.get_region(region)

			if SKIP_EMPTY and frame.is_invisible():
				index += 1
				continue

			var file_name : String
			if ROW_IN_NAME:
				file_name = "%s%d_%d.png" % [PREFIX, y, x]
			else:
				file_name = "%s%d.png" % [PREFIX, index]

			var err : int = frame.save_png(abs_out.path_join(file_name))
			if err != OK:
				push_error("Save failed : %s (error %d)" % [file_name, err])
			else:
				exported += 1
			index += 1

	print("Atlas slicer : %d / %d frames exported to %s" % [exported, index, OUTPUT_DIR])
	EditorInterface.get_resource_filesystem().scan()
