extends Node

var auto_parts : int

var dollar_weights : Dictionary = {
	DollarData.Rarities.COMMON: 500,
	DollarData.Rarities.RARE: 100,
	DollarData.Rarities.EPIC: 20,
	DollarData.Rarities.LEGENDARY: 1
}


const ALL_DOLLAR : Array = [
	preload("uid://ydtnmpfplfvu"),
	preload("uid://sqpp10ipav3a"),
	preload("uid://eplph6wq8wyy")
	]

var all_dollars : Array[DollarData] = []
var rng : RandomNumberGenerator = RandomNumberGenerator.new()
var fortune : int


func _ready() -> void:
	for dollar : DollarData in ALL_DOLLAR:
		all_dollars.append(dollar)
	fortune = 0
	auto_parts = 0
	rng.randomize()


func unload() -> void:
	auto_parts = 0
	fortune = 0


func pick_rarity() -> DollarData.Rarities:
	var weighted_sum : int = 0
	for rarity : DollarData.Rarities  in dollar_weights:
		weighted_sum += dollar_weights[rarity]
	
	var shop_item_weight : int = rng.randi_range(0,weighted_sum -1)
	
	for rarity : DollarData.Rarities in dollar_weights:
		shop_item_weight -= dollar_weights[rarity]
		if shop_item_weight < 0:
			return rarity
	return DollarData.Rarities.COMMON
  
func pick_dollar()-> DollarData:
	var rarity : DollarData.Rarities = pick_rarity()
	var pool : Array = all_dollars.filter(
		func(boost : DollarData) -> bool:
		return boost.rarity == rarity)
	
	if pool.is_empty():
		push_warning("shop manager : no boost with rarity "+ str(rarity))
		pool = all_dollars
	
	return pool[rng.randi_range(0,pool.size() -1)]
