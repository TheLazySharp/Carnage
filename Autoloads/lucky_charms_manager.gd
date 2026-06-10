extends Node

var holder : Array[CharmData]
var pool : Array[CharmData]
var holder_max_size : int = 5
var shuffled_pool_copy : Array[CharmData]

#const MAGIC_TREE_BLU = preload("uid://cis2ruvwfomdd")
#const MAGIC_TREE_GRE = preload("uid://bskee4ne4napf")
#const MAGIC_TREE_RED = preload("uid://dusp7r6wm1u2r")
#const MAGIC_TREE_YEL = preload("uid://ch5w70r2yphyu")


# ---- SWAP VAR -----
var swap_pool_index : int
var swap_holder_index : int
var swap_pool_lucky_charm : CharmData
var swap_holder_lucky_charm : CharmData
var lucky_charms_scene:= "uid://ch2rp03kbdyg7"
var undo_ok : bool = false
var add_lucky_charm_ok : bool = true
var shuffle_lucky_charms_ok : bool = true
var max_displayed_charms : int = 3
var selected_new_lucky_charms_index : int
var last_added_lucky_charm : CharmData = null

func _ready() -> void:
	randomize()
	init()
	
func init() -> void : 
	#pool.append(MAGIC_TREE_GRE)
	#pool.append(MAGIC_TREE_BLU)
	#pool.append(MAGIC_TREE_RED)
	#pool.append(MAGIC_TREE_YEL)
	holder = [null,null,null]

func shuffle() -> void : 
	pool.shuffle()
	shuffled_pool_copy = pool.slice(0, min(pool.size(),max_displayed_charms))


func unload() -> void : 
	pool.clear()
	holder.clear()
	init()

func call_reverse_swap() -> void : 
	if undo_ok: 
		reverse_swap(swap_pool_index,swap_holder_index,swap_pool_lucky_charm,swap_holder_lucky_charm)


func swap_lucky_charms(pool_index : int, holder_index : int, new_lucky_charm : CharmData, current_lucky_charm : CharmData) -> void : 
	undo_ok = true
	swap_pool_index = pool_index
	swap_holder_index = holder_index
	swap_pool_lucky_charm = new_lucky_charm
	swap_holder_lucky_charm = current_lucky_charm

	pool.erase(new_lucky_charm)
	holder.remove_at(holder_index)
	if current_lucky_charm != null :
		pool.append(current_lucky_charm)
	holder.insert(holder_index,new_lucky_charm)
	add_lucky_charm_ok = false
	#SceneManager.load_level(lucky_charms_scene)
	
func reverse_swap(pool_index : int, holder_index : int, pool_lucky_charm : CharmData, holder_lucky_charm : CharmData) -> void : 
	var appended_index : int = pool.rfind(holder_lucky_charm)
	if appended_index != -1 : 
		pool.remove_at(appended_index)
	pool.insert(pool_index,pool_lucky_charm)
	holder.remove_at(holder_index)
	holder.insert(holder_index,holder_lucky_charm)

	#SceneManager.load_level(lucky_charms_scene)
	add_lucky_charm_ok = true
	undo_ok = false
	
func apply_charm_modifier(lucky_charm : CharmData) -> void : 
	var new_mod : Modifier = Modifier.new(lucky_charm.modifier_value,lucky_charm.modifier_type,"new_lucky_charm",0)
	
	if lucky_charm.target_ressource == lucky_charm.Target_Ressources.CAR:
		CarManager.selected_car.get_car_stat(lucky_charm.target_car_stat).add_modifier(new_mod)
		print("car max life : ",CarManager.selected_car.max_life.get_value())
	
	if lucky_charm.target_ressource == lucky_charm.Target_Ressources.WEAPONS or lucky_charm.target_ressource == lucky_charm.Target_Ressources.AMMOS:
		for i : int in WeaponsManager.WEAPONS_TYPES[lucky_charm.weapon_type].size():
			var weapon : WeaponData = WeaponsManager.WEAPONS_TYPES[lucky_charm.weapon_type][i]
			weapon.get_weapon_stat(lucky_charm.target_weapon_stat).add_modifier(new_mod)
