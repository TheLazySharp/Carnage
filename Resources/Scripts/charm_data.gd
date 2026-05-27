extends Resource
class_name CharmData

enum Rarities {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY
}

@export var name: String
@export var icon: Texture2D
@export var description: String
@export var rarity: Rarities
var price: int
var is_in_shop : bool = false


@export var effect_script : GDScript

func get_rarity_string(boost_rarity : Rarities) -> String:
	match boost_rarity:
		Rarities.COMMON: return "Common"
		Rarities.RARE: return "Rare"
		Rarities.EPIC: return "Epic"
		Rarities.LEGENDARY: return "Legendary"
	return ""
	

func get_shop_color() -> Color:
	return ShopManager.item_colors[rarity]
