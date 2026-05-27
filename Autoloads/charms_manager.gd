extends Node

var active_charms: Dictionary = {}
var holder : Array[CharmData] = []

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
