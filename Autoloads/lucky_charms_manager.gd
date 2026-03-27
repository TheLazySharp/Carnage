extends Node

var holder : Array[LuckyCharmData]
var pool : Array[LuckyCharmData]
var holder_max_size : int = 5
var shuffled_pool_copy : Array[LuckyCharmData]

const MAGIC_TREE_BLU = preload("uid://cis2ruvwfomdd")
const MAGIC_TREE_GRE = preload("uid://bskee4ne4napf")
const MAGIC_TREE_RED = preload("uid://dusp7r6wm1u2r")
const MAGIC_TREE_YEL = preload("uid://ch5w70r2yphyu")

var life_bonus : float = 1.0
var max_speed_bonus : float = 1.0
var acceleration_bonus : float = 1.0
var damages_bonus : float = 1.0
var dash_damages_bonus : float = 1.0
var nitro_bonus : float = 1.0
var tires_bonus : float = 1.0
var magnetism_bonus : float = 1.0

var short_range_dmg_bonus : float = 1.0
var short_range_fire_rate_bonus : float = 1.0

var long_range_dmg_bonus : float = 1.0
var long_range_fire_rate_bonus : float = 1.0

var automatic_dmg_bonus : float = 1.0
var automatic_fire_rate_bonus : float = 1.0

var non_automatic_dmg_bonus : float = 1.0
var non_automatic_fire_rate_bonus : float = 1.0

var explosives_range_bonus : float = 1.0
var explosives_dmg_bonus : float = 1.0
var explosives_fire_rate_bonus : float = 1.0

var elemental_dmg_bonus : float = 1.0
var elemental_fire_rate_bonus : float = 1.0
var elemental_range_bonus : float = 1.0

var all_dmg_bonus : float = 1.0
var all_fire_rate_bonus : float = 1.0
var all_range_bonus : float = 1.0

# ---- SWAP VAR -----
var swap_pool_index : int
var swap_holder_index : int
var swap_pool_lucky_charm : LuckyCharmData
var swap_holder_lucky_charm : LuckyCharmData
var lucky_charms_scene:= "uid://ch2rp03kbdyg7"
var undo_ok : bool = false
var add_lucky_charm_ok : bool = true
var shuffle_lucky_charms_ok : bool = true
var max_displayed_charms : int = 3
var selected_new_lucky_charms_index : int

func _ready() -> void:
	randomize()
	init()
	
func init() -> void : 
	pool.append(MAGIC_TREE_GRE)
	pool.append(MAGIC_TREE_BLU)
	pool.append(MAGIC_TREE_RED)
	pool.append(MAGIC_TREE_YEL)
	holder = [null,null,null]

func shuffle() -> void : 
	pool.shuffle()
	shuffled_pool_copy.clear()
	for i in range(0, min(pool.size(),max_displayed_charms)):
		shuffled_pool_copy.append(pool[i])
	print(shuffled_pool_copy)

func unload() -> void : 
	pool.clear()
	holder.clear()
	init()
	update_lucky_charms_bonus()


func call_reverse_swap() -> void : 
	if undo_ok: 
		reverse_swap(swap_pool_index,swap_holder_index,swap_pool_lucky_charm,swap_holder_lucky_charm)


func update_lucky_charms_bonus() -> void :
	reset_bonuses()

	for i in holder.size():
		if holder[i] == null : 
			continue
		var lucky_charm : LuckyCharmData = holder[i]
		life_bonus *= lucky_charm.life_bonus
		max_speed_bonus *= lucky_charm.max_speed_bonus
		acceleration_bonus *= lucky_charm.acceleration_bonus
		damages_bonus *= lucky_charm.damages_bonus
		dash_damages_bonus *= lucky_charm.dash_damages_bonus
		nitro_bonus *= lucky_charm.nitro_bonus
		tires_bonus *= lucky_charm.tires_bonus
		magnetism_bonus *= lucky_charm.magnetism_bonus

		short_range_dmg_bonus *= lucky_charm.short_range_dmg_bonus
		short_range_fire_rate_bonus *= lucky_charm.short_range_fire_rate_bonus

		long_range_dmg_bonus *= lucky_charm.long_range_dmg_bonus
		long_range_fire_rate_bonus *= lucky_charm.long_range_fire_rate_bonus

		automatic_dmg_bonus *= lucky_charm.automatic_dmg_bonus
		automatic_fire_rate_bonus *= lucky_charm.automatic_fire_rate_bonus

		non_automatic_dmg_bonus *= lucky_charm.non_automatic_dmg_bonus
		non_automatic_fire_rate_bonus *= lucky_charm.non_automatic_fire_rate_bonus

		explosives_range_bonus *= lucky_charm.explosives_range_bonus
		explosives_dmg_bonus *= lucky_charm.explosives_dmg_bonus
		explosives_fire_rate_bonus *= lucky_charm.explosives_fire_rate_bonus

		elemental_dmg_bonus *= lucky_charm.elemental_dmg_bonus
		elemental_fire_rate_bonus *= lucky_charm.elemental_fire_rate_bonus
		elemental_range_bonus *= lucky_charm.elemental_fire_rate_bonus

		all_dmg_bonus *= lucky_charm.all_dmg_bonus
		all_fire_rate_bonus *= lucky_charm.all_fire_rate_bonus
		all_range_bonus *= lucky_charm.all_range_bonus
	
	StatsManager.update_car_stats(CarManager.selected_car)

func swap_lucky_charms(pool_index : int, holder_index : int, new_lucky_charm : LuckyCharmData, current_lucky_charm : LuckyCharmData) -> void : 
	undo_ok = true
	swap_pool_index = pool_index
	swap_holder_index = holder_index
	swap_pool_lucky_charm = new_lucky_charm
	swap_holder_lucky_charm = current_lucky_charm

	pool.remove_at(pool_index)
	holder.remove_at(holder_index)
	if current_lucky_charm != null :
		pool.append(current_lucky_charm)
	holder.insert(holder_index,new_lucky_charm)
	add_lucky_charm_ok = false
	SceneManager.load_level(lucky_charms_scene)
	
func reverse_swap(pool_index : int, holder_index : int, pool_lucky_charm : LuckyCharmData, holder_lucky_charm : LuckyCharmData) -> void : 
	pool.insert(pool_index,pool_lucky_charm)
	pool.erase(holder_lucky_charm)
	holder.insert(holder_index,holder_lucky_charm)
	holder.erase(pool_lucky_charm)
	
	SceneManager.load_level(lucky_charms_scene)
	add_lucky_charm_ok = true
	undo_ok = false

func reset_bonuses()-> void : 
	life_bonus = 1.0
	max_speed_bonus = 1.0
	acceleration_bonus = 1.0
	damages_bonus = 1.0
	dash_damages_bonus = 1.0
	nitro_bonus = 1.0
	tires_bonus = 1.0
	magnetism_bonus = 1.0

	short_range_dmg_bonus = 1.0
	short_range_fire_rate_bonus = 1.0

	long_range_dmg_bonus = 1.0
	long_range_fire_rate_bonus = 1.0

	automatic_dmg_bonus = 1.0
	automatic_fire_rate_bonus = 1.0

	non_automatic_dmg_bonus = 1.0
	non_automatic_fire_rate_bonus = 1.0

	explosives_range_bonus = 1.0
	explosives_dmg_bonus = 1.0
	explosives_fire_rate_bonus = 1.0

	elemental_dmg_bonus = 1.0
	elemental_fire_rate_bonus = 1.0
	elemental_range_bonus = 1.0

	all_dmg_bonus = 1.0
	all_fire_rate_bonus = 1.0
	all_range_bonus = 1.0
