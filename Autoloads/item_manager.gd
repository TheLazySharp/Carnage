extends Node

var active_items: Dictionary = {}
var holder : Array[ItemData] = []


var all_items : Array[ItemData] = []
var rng : RandomNumberGenerator = RandomNumberGenerator.new()

const ALL_ITEMS : Array = [
	preload("uid://wnsnxcswp71k"), #magnet
	preload("uid://c8r7ijia7d2fh"), #freeze
	preload("uid://dxmsrsehqdpys"), #nitro up
	preload("uid://djm0jm8xnf3kx"), #gas
	preload("uid://cgudfa8adx5u1"), #repair 25% of the missing life
	preload("uid://dcmwnvhsjlkph"), #wallet
	
]


@warning_ignore("unused_signal")
signal freeze
@warning_ignore("unused_signal")
signal magnet_xp
@warning_ignore("unused_signal")
signal nitro_up(nitro_added : float)
@warning_ignore("unused_signal")
signal gas
@warning_ignore("unused_signal")
signal repair(reparation : float)
@warning_ignore("unused_signal")
signal wallet

func _ready() -> void:
	rng.randomize()


func load_pools() -> void : 
	for item : ItemData in ALL_ITEMS:
		all_items.append(item)

func pick_item() -> ItemData:
	if all_items.is_empty():
		print("no items in item_manager pool")
		return null
	return all_items[rng.randi_range(0,all_items.size() -1)]

func register(item: ItemData, effect: ItemEffect) -> void:
	active_items[item] = effect
	holder.append(item)

func deactivate_all() -> void:
	for effect : ItemEffect in active_items.values():
		effect.deactivate()
	active_items.clear()
	
func unload() -> void : 
	for effect : ItemEffect in active_items.values():
		effect.deactivate()
	active_items.clear()
	holder.clear()
