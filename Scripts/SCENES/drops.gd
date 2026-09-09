extends Control

@onready var drops_container: GridContainer = $DropsContainer

var drop : FreeDropsData
var rng : RandomNumberGenerator = RandomNumberGenerator.new()
var nb_drops : int = 2
var boosts_drops : Array[BoostData] = []
var charms_drops : Array[CharmData] = []
var drop_rarity : BoostData.Rarities


var drops_rarity_weights : Dictionary = {
	BoostData.Rarities.EPIC: 7,
	BoostData.Rarities.LEGENDARY: 3
}

func _ready() -> void:
	if InventoryManager.free_drops.is_empty():
		return
	drop = InventoryManager.free_drops[0]

func _on_open_pressed() -> void:
	drop_rarity = set_rarity()
	#print(rarity)
	#pick_boost()
	

func set_rarity() -> BoostData.Rarities:
	var weighted_sum : int = 0
	for rarity : BoostData.Rarities  in drops_rarity_weights:
		weighted_sum += drops_rarity_weights[rarity]
	
	var pick_weight : int = rng.randi_range(0,weighted_sum -1)
	for rarity : BoostData.Rarities in drops_rarity_weights:
		pick_weight -= drops_rarity_weights[rarity]
		if pick_weight < 0:
			return rarity
	return BoostData.Rarities.EPIC


func pick_drops() -> void : 
	match drop.type:
		FreeDropsData.TYPES.CAR_UPGRADE:
			pick_boost(boosts_drops, ShopManager.all_car_boosts,drop_rarity)
		FreeDropsData.TYPES.WEAPON_UPGRADE:
			pick_boost(boosts_drops, ShopManager.all_weapon_boosts,drop_rarity)
		FreeDropsData.TYPES.AMMO_UPGRADE:
			pick_boost(boosts_drops, ShopManager.all_ammo_boosts,drop_rarity)
		FreeDropsData.TYPES.CHARM:
			pick_charm(charms_drops, ShopManager.all_charms,drop_rarity)




func pick_boost(proposed_drops : Array[BoostData], pick_list : Array[BoostData], rarity : BoostData.Rarities) -> BoostData:
	var attempts : int = 0
	while attempts <1000:
		attempts += 1
		var boost : BoostData = ShopManager.pick_boost(pick_list)
		
		if proposed_drops.has(boost):
			continue
		if boost.target_weapon != null and !WeaponsManager.weapons.has(boost.target_weapon):
			continue
		if boost.target_weapon != null and proposed_drops.any(
				func(check : BoostData) -> bool: return InventoryManager.get_boost_name(check) == InventoryManager.get_boost_name(boost)):
			continue
		
		return boost
	push_warning("drops.tscn : no valid charm found after 1000 attempts")
	return null
	
func pick_charm(proposed_drops : Array[CharmData], pick_list : Array[CharmData], rarity : BoostData.Rarities) -> CharmData:
	var attempts : int = 0
	while attempts <1000:
		attempts += 1
		var charm : CharmData = ShopManager.pick_charm()
		
		if proposed_drops.has(charm):
			continue
		if CharmsManager.holder.has(charm):
			continue
		
		return charm
	push_warning("drops.tscn : no valid charm found after 1000 attempts")
	return null
