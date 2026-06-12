extends Node

var active_charms: Dictionary = {}
var holder : Array[CharmData] = []

enum Rarities {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY
}

var invincibility_duration : Dictionary = {
	Rarities.COMMON: 3,
	Rarities.RARE: 5,
	Rarities.EPIC: 6,
	Rarities.LEGENDARY: 8
}

var nb_projectile_added : Dictionary = {
	Rarities.COMMON: 1,
	Rarities.RARE: 2,
	Rarities.EPIC: 3,
	Rarities.LEGENDARY: 5
}


func register(charm: CharmData, effect: CharmEffect) -> void:
	active_charms[charm] = effect
	holder.append(charm)

func deactivate_all() -> void:
	for effect : CharmEffect in active_charms.values():
		effect.deactivate()
	active_charms.clear()
	
func unload() -> void : 
	for effect : CharmEffect in active_charms.values():
		effect.deactivate()
	active_charms.clear()
	holder.clear()
