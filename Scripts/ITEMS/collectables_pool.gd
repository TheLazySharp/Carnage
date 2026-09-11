class_name CollectablePool
extends Node2D

# FREE-LIST POOL
# XP orbs and dollars stay on the ground until picked up, so their lifetime is
# unpredictable: a ring buffer would steal uncollected ones. A free list gives
# O(1) acquire and release with no scan. If the pool ever runs dry, the oldest
# slot is recycled rather than instantiating in the middle of a fight.

@export_group("SCENES")
@export var xp_scene : PackedScene
@export var dollar_scene : PackedScene
@export var xp_pool_size : int = 400
@export var dollar_pool_size : int = 200

var xp_items : Array[Node2D] = []
var dollar_items : Array[Node2D] = []
var xp_free : Array[int] = []
var dollar_free : Array[int] = []
var xp_steal_cursor : int = 0
var dollar_steal_cursor : int = 0
## SpriteFrames built once per XPData instead of once per orb
var xp_frames_cache : Dictionary = {}


func _ready() -> void:
	xp_items.resize(xp_pool_size)
	xp_free.resize(xp_pool_size)
	for i : int in range(xp_pool_size):
		var item : Node2D = xp_scene.instantiate()
		add_child(item)
		item.setup_pooled(self, i)
		xp_items[i] = item
		xp_free[i] = xp_pool_size - 1 - i  # stack: pop_back() hands out index 0 first

	dollar_items.resize(dollar_pool_size)
	dollar_free.resize(dollar_pool_size)
	for i : int in range(dollar_pool_size):
		var item : Node2D = dollar_scene.instantiate()
		add_child(item)
		item.setup_pooled(self, i)
		dollar_items[i] = item
		dollar_free[i] = dollar_pool_size - 1 - i


## Public API: replaces xp_scene.instantiate() + add_child() + launch_spawn()
func spawn_xp(spawn_position : Vector2, data : XPData) -> void:
	xp_items[_acquire_xp()].activate(spawn_position, data)


func spawn_dollar(spawn_position : Vector2) -> void:
	dollar_items[_acquire_dollar()].activate(spawn_position)


func release_xp(index : int) -> void:
	var item : Node2D = xp_items[index]
	if not item.is_active:
		return  # never let the same index enter the free list twice
	item.deactivate()
	xp_free.push_back(index)


func release_dollar(index : int) -> void:
	var item : Node2D = dollar_items[index]
	if not item.is_active:
		return
	item.deactivate()
	dollar_free.push_back(index)


## Wipes the ground, e.g. on a new day. Wire it to a signal if the design needs it.
func release_all() -> void:
	for i : int in xp_items.size():
		release_xp(i)
	for i : int in dollar_items.size():
		release_dollar(i)


## SpriteFrames are identical for every orb sharing an XPData: build them once.
## This used to allocate one SpriteFrames + hframes AtlasTextures per kill.
func get_xp_frames(data : XPData) -> SpriteFrames:
	if xp_frames_cache.has(data):
		return xp_frames_cache[data]
	var frames : SpriteFrames = SpriteFrames.new()
	frames.add_animation("blooming")
	frames.set_animation_loop("blooming", true)
	frames.set_animation_speed("blooming", data.fps)
	var texture : Texture2D = data.spritesheet
	@warning_ignore("integer_division")
	var frame_width : int = texture.get_width() / data.hframes
	@warning_ignore("integer_division")
	var frame_height : int = texture.get_height() / data.vframes
	for i : int in data.hframes:
		var atlas : AtlasTexture = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * frame_width, data.row * frame_height, frame_width, frame_height)
		frames.add_frame("blooming", atlas)
	xp_frames_cache[data] = frames
	return frames


func _acquire_xp() -> int:
	if xp_free.is_empty():
		var stolen : int = xp_steal_cursor
		xp_steal_cursor = (xp_steal_cursor + 1) % xp_items.size()
		xp_items[stolen].deactivate()  # direct, not release: it must not re-enter the free list
		push_warning("CollectablePool: XP pool exhausted, recycling oldest orb")
		return stolen
	return xp_free.pop_back()


func _acquire_dollar() -> int:
	if dollar_free.is_empty():
		var stolen : int = dollar_steal_cursor
		dollar_steal_cursor = (dollar_steal_cursor + 1) % dollar_items.size()
		dollar_items[stolen].deactivate()
		push_warning("CollectablePool: dollar pool exhausted, recycling oldest one")
		return stolen
	return dollar_free.pop_back()
