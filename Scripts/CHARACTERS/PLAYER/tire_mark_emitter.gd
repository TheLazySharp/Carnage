extends Node2D
class_name TireMarks
## Stamps tire marks along its own path while emitting (place it on a wheel).
## Marks are grouped in chunks that fade out on their own, even once the emitter is gone

enum RotationMode { NONE, RANDOM_90, FOLLOW_DIRECTION, FOLLOW_DIRECTION_45 }

## A jump bigger than this in one frame is a teleport: no mark across it
const TELEPORT_DISTANCE : float = 600.0

@export_group("Emission")
## Driven by the owner (DriftManager): true while the tires skid. Only processes while true
@export var emitting : bool = false:
	set(value):
		if value == emitting:
			return
		emitting = value
		has_last_pos = false
		set_process(value)
		if mark_layer == null or !is_instance_valid(mark_layer):
			return
		if value:
			_sync_layer()  # settings and tint changed since the last skid apply to the new marks
		else:
			mark_layer.end_chunk()

@export_group("Stamps")
## Folder of stamp textures. Ignored if stamp_textures is filled
@export_dir var stamp_folder : String = ""
@export var stamp_textures : Array[Texture2D] = []
## Snaps the stamps on the pixel grid
@export var pixel_size : int = 1
## Distance between two stamps (px)
@export_range(0.5, 64.0, 0.5, "or_greater") var spacing : float = 4.0
@export var spacing_jitter : float = 0.0
@export var perpendicular_jitter : float = 0.0
## FOLLOW_*: textures must be drawn facing right (+X)
@export var rotation_mode : RotationMode = RotationMode.RANDOM_90
@export var allow_flip : bool = true

@export_group("Lifetime and color")
## Time between the last stamp of a chunk and its full disappearance (s)
@export_range(0.1, 30.0, 0.1, "or_greater") var lifetime : float = 4.0
## Share of lifetime kept at full alpha before fading (0 = fades right away)
@export_range(0.0, 0.95, 0.01) var fade_delay_ratio : float = 0.3
## Chunk color (alpha included), stored at chunk creation: a change only affects new marks
@export var tint : Color = Color.WHITE

@export_group("Performance")
## Chunk length (px). Shorter = finer fade but more nodes
@export_range(16.0, 512.0, 1.0, "or_greater") var chunk_length : float = 96.0
## Max chunks per emitter: the oldest one is removed beyond it
@export_range(1, 200, 1) var max_chunks : int = 40
## true: overlapping stamps of a chunk merge without darkening (one CanvasGroup per chunk, costly).
## false: lighter, but overlapping semi transparent stamps darken
@export var merge_overlap : bool = true

@export_group("Rendering")
## z_index of the marks inside their parent
@export var marks_z_index : int = 0

## Node hosting the marks, set by the owner. Falls back to the current scene
var mark_parent : Node = null

static var folder_cache : Dictionary[String, Array] = {}

var rng : RandomNumberGenerator = RandomNumberGenerator.new()
var textures : Array[Texture2D] = []
var mark_layer : MarkLayer = null
var has_last_pos : bool = false
var last_pos : Vector2 = Vector2.ZERO
var carry : float = 0.0     # distance walked since the last stamp
var next_gap : float = 0.0  # distance to walk before the next stamp


func _ready() -> void:
	rng.randomize()
	_load_textures()
	set_process(emitting)


func _exit_tree() -> void:
	# Marks already laid finish fading even if the car is gone
	if mark_layer != null and is_instance_valid(mark_layer):
		mark_layer.end_chunk()
		mark_layer.detached = true
		mark_layer.set_process(true)  # wakes it up so it frees itself once empty
	mark_layer = null


## Erases every mark of this emitter right away
func clear_marks() -> void:
	if mark_layer != null and is_instance_valid(mark_layer):
		mark_layer.clear_all()


func _process(_delta : float) -> void:
	_emit_along(global_position)


func _emit_along(pos : Vector2) -> void:
	if !has_last_pos:
		last_pos = pos
		has_last_pos = true
		carry = 0.0
		next_gap = 0.0

	var segment : Vector2 = pos - last_pos
	var segment_length : float = segment.length()
	if segment_length < 0.001:
		return

	if segment_length > TELEPORT_DISTANCE:
		has_last_pos = false
		if mark_layer != null and is_instance_valid(mark_layer):
			mark_layer.end_chunk()
		return

	var direction : Vector2 = segment / segment_length
	var walked : float = 0.0

	# Stamps at regular intervals along the real wheel path, even over several gaps in one frame
	while true:
		var needed : float = next_gap - carry
		if walked + needed > segment_length:
			carry += segment_length - walked
			break
		walked += needed
		_place_stamp(last_pos + direction * walked, direction, maxf(next_gap, 0.001))
		carry = 0.0
		next_gap = _pick_gap()

	last_pos = pos


func _pick_gap() -> float:
	var jitter : float = 0.0
	if spacing_jitter > 0.0:
		jitter = rng.randf_range(-spacing_jitter, spacing_jitter)
	return maxf(spacing + jitter, 0.5)


func _place_stamp(world_pos : Vector2, direction : Vector2, advance : float) -> void:
	if textures.is_empty():
		return
	var target_layer : MarkLayer = _ensure_layer()
	if target_layer == null:
		return

	var offset : Vector2 = Vector2.ZERO
	if perpendicular_jitter > 0.0:
		offset = direction.orthogonal() * rng.randf_range(-perpendicular_jitter, perpendicular_jitter)
	var grid : Vector2 = Vector2(pixel_size, pixel_size)
	var stamp_position : Vector2 = target_layer.to_local((world_pos + offset).snapped(grid))

	var stamp_rotation : float = 0.0
	match rotation_mode:
		RotationMode.RANDOM_90:
			stamp_rotation = rng.randi_range(0, 3) * (PI * 0.5)
		RotationMode.FOLLOW_DIRECTION:
			stamp_rotation = direction.angle()
		RotationMode.FOLLOW_DIRECTION_45:
			stamp_rotation = snappedf(direction.angle(), PI * 0.25)

	var flip : Vector2 = Vector2.ONE
	if allow_flip:
		flip.x = -1.0 if rng.randi_range(0, 1) == 1 else 1.0
		flip.y = -1.0 if rng.randi_range(0, 1) == 1 else 1.0

	var texture : Texture2D = textures[rng.randi_range(0, textures.size() - 1)]
	target_layer.add_stamp(texture, stamp_position, stamp_rotation, flip, advance, chunk_length)


func _ensure_layer() -> MarkLayer:
	if mark_layer != null and is_instance_valid(mark_layer):
		return mark_layer
	var host : Node = mark_parent if is_instance_valid(mark_parent) else get_tree().current_scene
	if host == null:
		return null
	mark_layer = MarkLayer.new()
	mark_layer.name = "TireMarkLayer"
	host.add_child(mark_layer)
	_sync_layer()
	return mark_layer


func _sync_layer() -> void:
	mark_layer.life_seconds = lifetime
	mark_layer.fade_delay_ratio = fade_delay_ratio
	mark_layer.max_chunks = max_chunks
	mark_layer.merge_overlap = merge_overlap
	mark_layer.current_tint = tint
	mark_layer.z_index = marks_z_index


func _load_textures() -> void:
	textures.clear()
	for texture : Texture2D in stamp_textures:
		if texture != null:
			textures.append(texture)
	if textures.is_empty() and stamp_folder != "":
		textures = _load_folder(stamp_folder)
	if textures.is_empty():
		push_warning("TireMarks: no texture (stamp_textures or stamp_folder)")


## Cached per folder: both rear wheels share the same loads. Works in exported games
static func _load_folder(folder : String) -> Array[Texture2D]:
	if !folder_cache.has(folder):
		var loaded : Array[Texture2D] = []
		var files : PackedStringArray = ResourceLoader.list_directory(folder)
		files.sort()
		for file : String in files:
			if file.ends_with("/"):
				continue  # sub folder
			var texture : Texture2D = load(folder.path_join(file)) as Texture2D
			if texture != null:
				loaded.append(texture)
		folder_cache[folder] = loaded
	var result : Array[Texture2D] = []
	result.assign(folder_cache[folder])
	return result


## Draws every stamp of one chunk in a single node, and holds the chunk state
class ChunkSurface extends Node2D:
	var stamp_textures : Array[Texture2D] = []
	var stamp_positions : PackedVector2Array = PackedVector2Array()
	var stamp_rotations : PackedFloat32Array = PackedFloat32Array()
	var stamp_flips : PackedVector2Array = PackedVector2Array()
	var root : CanvasItem = null  # node faded and freed: the CanvasGroup, or this surface
	var tint : Color = Color.WHITE
	var last_stamp_time : float = 0.0
	var length : float = 0.0
	var life : float = 4.0  # lifetime stored at creation: drift and slide marks differ

	func add_stamp(texture : Texture2D, stamp_position : Vector2, stamp_rotation : float, flip : Vector2) -> void:
		stamp_textures.append(texture)
		stamp_positions.append(stamp_position)
		stamp_rotations.append(stamp_rotation)
		stamp_flips.append(flip)
		queue_redraw()

	func _draw() -> void:
		for i : int in stamp_textures.size():
			var texture : Texture2D = stamp_textures[i]
			# Whole pixel offset: corners stay on the pixel grid, even for odd sizes, rotations and flips
			var half : Vector2 = (texture.get_size() * 0.5).floor()
			draw_set_transform(stamp_positions[i], stamp_rotations[i], stamp_flips[i])
			draw_texture(texture, -half)


## Holds the chunks of one emitter: creates, ages and frees them, even once the emitter is gone
class MarkLayer extends Node2D:
	var chunks : Array[ChunkSurface] = []  # sorted from oldest to newest
	var current : ChunkSurface = null
	var clock : float = 0.0
	var life_seconds : float = 4.0
	var fade_delay_ratio : float = 0.3
	var max_chunks : int = 40
	var merge_overlap : bool = true
	var current_tint : Color = Color.WHITE
	var detached : bool = false

	func add_stamp(texture : Texture2D, stamp_position : Vector2, stamp_rotation : float, flip : Vector2, advance : float, chunk_length : float) -> void:
		if current == null:
			_begin_chunk()
		current.add_stamp(texture, stamp_position, stamp_rotation, flip)
		current.last_stamp_time = clock
		current.length += advance
		if current.length >= chunk_length:
			end_chunk()

	func end_chunk() -> void:
		current = null

	func clear_all() -> void:
		for chunk : ChunkSurface in chunks:
			chunk.root.queue_free()
		chunks.clear()
		current = null

	func _begin_chunk() -> void:
		if chunks.size() >= max_chunks:
			_drop_oldest()
		var chunk : ChunkSurface = ChunkSurface.new()
		if merge_overlap:
			var group : CanvasGroup = CanvasGroup.new()
			add_child(group)
			group.add_child(chunk)
			chunk.root = group
		else:
			add_child(chunk)
			chunk.root = chunk
		chunk.tint = current_tint
		chunk.life = maxf(life_seconds, 0.001)
		chunk.last_stamp_time = clock
		chunk.root.self_modulate = current_tint
		chunks.append(chunk)
		current = chunk
		set_process(true)

	func _drop_oldest() -> void:
		if chunks.is_empty():
			return
		var oldest : ChunkSurface = chunks.pop_front()
		if oldest == current:
			current = null
		oldest.root.queue_free()

	func _process(delta : float) -> void:
		if chunks.is_empty():
			# Nothing left to fade: sleep until the next chunk, or leave if the emitter is gone
			if detached:
				queue_free()
			else:
				set_process(false)
			return

		clock += delta
		var delay : float = clampf(fade_delay_ratio, 0.0, 0.95)
		# Each chunk has its own lifetime: walk backward to remove the expired ones safely
		for i : int in range(chunks.size() - 1, -1, -1):
			var chunk : ChunkSurface = chunks[i]
			var age_ratio : float = (clock - chunk.last_stamp_time) / chunk.life
			if age_ratio >= 1.0:
				if chunk == current:
					current = null
				chunk.root.queue_free()
				chunks.remove_at(i)
				continue
			var color : Color = chunk.tint
			if age_ratio > delay:
				color.a *= 1.0 - (age_ratio - delay) / (1.0 - delay)
			chunk.root.self_modulate = color
