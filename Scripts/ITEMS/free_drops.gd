extends Area2D

var drop : FreeDropsData
var type : FreeDropsData.TYPES

func _ready() -> void:
	drop = null
	match RoadMapManager.last_district.type:
		DistrictsData.types.GUNSHOP:
			type = FreeDropsData.TYPES.WEAPON_UPGRADE
		DistrictsData.types.CARDEALER:
			type = FreeDropsData.TYPES.CAR_UPGRADE
		DistrictsData.types.SUPERMARKET:
			type = FreeDropsData.TYPES.CHARM


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		InventoryManager.free_drop = true
		InventoryManager.free_drops.append(drop)
