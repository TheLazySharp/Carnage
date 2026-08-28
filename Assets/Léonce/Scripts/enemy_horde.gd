extends Node2D

# --- Config ---
const GRID_CELL := 32.0
const ANIM_SPEED := 6.0
const MAX_ENTITIES := 256
const MAX_NEIGHBORS := 8

@export var mmi_zombie: MultiMeshInstance2D
@export var mmi_slasher: MultiMeshInstance2D

var positions: PackedVector2Array = PackedVector2Array()
var velocities: PackedVector2Array = PackedVector2Array()
var half_sizes: PackedFloat32Array = PackedFloat32Array()   # sert UNIQUEMENT au broad-phase (test large)
var anim_time: PackedFloat32Array = PackedFloat32Array()
var type_id: PackedInt32Array = PackedInt32Array()
var grid: Dictionary = {}

# ⚠️ remplace cell_size/rows/cols par tes vraies valeurs mesurées
var type_defs: Array[Dictionary] = [
	{ "mmi": null, "cell_size": 16.0, "rows": 1, "cols": 16 },  # zombie
	{ "mmi": null, "cell_size": 25.0, "rows": 1, "cols": 1 },  # slasher
]

var entity_image: Image
var entity_texture: ImageTexture
var neighbor_image: Image
var neighbor_texture: ImageTexture

func _ready() -> void:
	assert(mmi_zombie != null, "mmi_zombie non assigné")
	assert(mmi_slasher != null, "mmi_slasher non assigné")

	type_defs[0]["mmi"] = mmi_zombie
	type_defs[1]["mmi"] = mmi_slasher

	for def: Dictionary in type_defs:
		_setup_multimesh(def)

	entity_image = Image.create(MAX_ENTITIES, 2, false, Image.FORMAT_RGBAF)
	entity_texture = ImageTexture.create_from_image(entity_image)
	neighbor_image = Image.create(MAX_ENTITIES, 2, false, Image.FORMAT_RGBAF)
	neighbor_texture = ImageTexture.create_from_image(neighbor_image)

	for def: Dictionary in type_defs:
		var mat: ShaderMaterial = def.mmi.material
		mat.set_shader_parameter("entity_data", entity_texture)
		mat.set_shader_parameter("neighbor_data", neighbor_texture)
		mat.set_shader_parameter("atlas_0", type_defs[0].mmi.texture)
		mat.set_shader_parameter("atlas_1", type_defs[1].mmi.texture)
		mat.set_shader_parameter("cell_size_0", type_defs[0].cell_size)
		mat.set_shader_parameter("cell_size_1", type_defs[1].cell_size)
		mat.set_shader_parameter("rows_0", type_defs[0].rows)
		mat.set_shader_parameter("cols_0", type_defs[0].cols)
		mat.set_shader_parameter("rows_1", type_defs[1].rows)
		mat.set_shader_parameter("cols_1", type_defs[1].cols)

	_spawn_test_enemies()

func _setup_multimesh(def: Dictionary) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	var cs: float = def.cell_size
	quad.size = Vector2(cs, cs)
	mm.mesh = quad

	var mmi: MultiMeshInstance2D = def.mmi
	mmi.multimesh = mm

	var mat: ShaderMaterial = mmi.material
	mat.set_shader_parameter("my_total_rows", def.rows)
	mat.set_shader_parameter("my_max_cols", def.cols)

func _spawn_test_enemies() -> void:
	var counts: Array[int] = [80, 15]  # zombies, slashers
	var total: int = min(counts[0] + counts[1], MAX_ENTITIES)

	positions.resize(total)
	velocities.resize(total)
	half_sizes.resize(total)
	anim_time.resize(total)
	type_id.resize(total)

	var idx: int = 0
	for t in 2:
		var n_count: int = counts[t]
		var cell_size: float = type_defs[t].cell_size
		for n in n_count:
			if idx >= total:
				break
			positions[idx] = Vector2(randf_range(0, 300), randf_range(0, 200))
			velocities[idx] = Vector2.RIGHT.rotated(randf_range(0, TAU)) * randf_range(15, 25)
			half_sizes[idx] = cell_size / 2.0
			anim_time[idx] = randf() * 4.0
			type_id[idx] = t
			idx += 1

	_refresh_instance_counts(counts)

func _refresh_instance_counts(counts: Array[int]) -> void:
	var mm0: MultiMesh = type_defs[0].mmi.multimesh
	var mm1: MultiMesh = type_defs[1].mmi.multimesh
	mm0.instance_count = counts[0]
	mm1.instance_count = counts[1]

func _process(delta: float) -> void:
	_update_movement(delta)
	_rebuild_grid()
	_update_entity_texture()
	_update_neighbor_texture()
	_push_to_multimeshes()

func _update_movement(delta: float) -> void:
	for i in positions.size():
		positions[i] += velocities[i] * delta
		anim_time[i] += delta * ANIM_SPEED
		if positions[i].x < 0 or positions[i].x > 300:
			velocities[i].x *= -1
		if positions[i].y < 0 or positions[i].y > 200:
			velocities[i].y *= -1

func _rebuild_grid() -> void:
	grid.clear()
	for i in positions.size():
		var key := Vector2i(floor(positions[i].x / GRID_CELL), floor(positions[i].y / GRID_CELL))
		if not grid.has(key):
			grid[key] = [] as Array[int]
		var bucket: Array[int] = grid[key]
		bucket.append(i)

# --- Broad-phase : qui POURRAIT toucher qui (marge large, pas besoin d'être exact) ---
func _find_candidates(i: int) -> Array[int]:
	var result: Array[int] = []
	var cell := Vector2i(floor(positions[i].x / GRID_CELL), floor(positions[i].y / GRID_CELL))
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			var key := cell + Vector2i(dx, dy)
			if not grid.has(key):
				continue
			var bucket_list: Array[int] = grid[key]
			for j: int in bucket_list:
				if j == i:
					continue
				var reach: float = half_sizes[i] + half_sizes[j]
				if positions[i].distance_to(positions[j]) < reach:
					result.append(j)
					if result.size() >= MAX_NEIGHBORS:
						return result
	return result

func _update_entity_texture() -> void:
	for i in positions.size():
		var t: int = type_id[i]
		var def: Dictionary = type_defs[t]
		var cols: int = def.cols
		var frame: int = int(anim_time[i]) % cols
		entity_image.set_pixel(i, 0, Color(positions[i].x, positions[i].y, float(t), 0.0))
		entity_image.set_pixel(i, 1, Color(0.0, float(frame), 0.0, 0.0))  # row, col
	entity_texture.update(entity_image)

func _update_neighbor_texture() -> void:
	for i in positions.size():
		var candidates: Array[int] = _find_candidates(i)
		var vals: Array[float] = [-1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0]
		for k in candidates.size():
			if k >= MAX_NEIGHBORS:
				break
			vals[k] = float(candidates[k])
		neighbor_image.set_pixel(i, 0, Color(vals[0], vals[1], vals[2], vals[3]))
		neighbor_image.set_pixel(i, 1, Color(vals[4], vals[5], vals[6], vals[7]))
	neighbor_texture.update(neighbor_image)

func _push_to_multimeshes() -> void:
	var local_idx: Array[int] = [0, 0]
	for i in positions.size():
		var t: int = type_id[i]
		var def: Dictionary = type_defs[t]
		var mm: MultiMesh = def.mmi.multimesh
		var li: int = local_idx[t]
		var cols: int = def.cols

		mm.set_instance_transform_2d(li, Transform2D(0.0, positions[i]))

		var frame: int = int(anim_time[i]) % cols
		mm.set_instance_custom_data(li, Color(
			0.0,             # r: anim_row (valeur brute, PAS normalisée)
			float(frame),    # g: frame_col (valeur brute)
			float(i),        # b: index global de l'entité
			0.0              # a: flip_h (0.0 ou 1.0)
		))
		local_idx[t] += 1
