extends Node

var item_levels : Dictionary = {
	BoostData.Rarities.COMMON: 500,
	BoostData.Rarities.RARE: 100,
	BoostData.Rarities.EPIC: 20,
	BoostData.Rarities.LEGENDARY: 1
}

var price_levels : Dictionary = {
	BoostData.Rarities.COMMON: 10,
	BoostData.Rarities.RARE: 20,
	BoostData.Rarities.EPIC: 100,
	BoostData.Rarities.LEGENDARY: 300
}

var item_colors : Dictionary = {
	BoostData.Rarities.COMMON:Color.WHITE,
	BoostData.Rarities.RARE:Color.RED,
	BoostData.Rarities.EPIC:Color.YELLOW,
	BoostData.Rarities.LEGENDARY:Color.PURPLE
}

var all_boosts : Array[BoostData] = []
var rng : RandomNumberGenerator = RandomNumberGenerator.new()
var available_boosts : int = 1
var boost_shopped : int = 0


func _ready() -> void:
	rng.randomize()
	load_boosts_from_folder("res://Resources/Boosts/EngineBoosts/")
	load_boosts_from_folder("res://Resources/Boosts/WeaponsBoosts/")
	

func pick_rarity() -> BoostData.Rarities:
	var weighted_sum : int = 0
	for rarity : BoostData.Rarities  in item_levels:
		weighted_sum += item_levels[rarity]
	
	var shop_item_weight : int = rng.randi_range(0,weighted_sum -1)
	
	for rarity : BoostData.Rarities in item_levels:
		shop_item_weight -= item_levels[rarity]
		if shop_item_weight < 0:
			return rarity
	return BoostData.Rarities.COMMON
  
func pick_boost()-> BoostData:
	var rarity : BoostData.Rarities = pick_rarity()
	var pool : Array = all_boosts.filter(
		func(boost : BoostData) -> bool:
		return boost.rarity == rarity)
	
	if pool.is_empty():
		push_warning("shop manager : no boost with rarity "+ str(rarity))
		pool = all_boosts
	
	return pool[rng.randi_range(0,pool.size() -1)]
	

func load_boosts_from_folder(path : String) -> void : 
	var dir := DirAccess.open(path)
	if !dir:
		push_error("shop manager : no folder in "+path)
		return
	
	dir.list_dir_begin()
	var file_name : String = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var full_path : String = path + file_name
			var resource : Resource = load(full_path)
			if resource is BoostData:
				all_boosts.append(resource)
			else : 
				push_error("shop manager : resource is not of type BoostData : "+full_path)
		file_name = dir.get_next()
	dir.list_dir_end()

func unload() -> void : 
	all_boosts.clear()
