extends Resource
class_name CharmData

@export var name: ShopManager.Items_Name
@export var icon: Texture2D
@export var description: String
@export var rarity: CharmsManager.Rarities
var price: int
var is_in_shop : bool = false
@export var p_value : float
@export var p_value_descr : String


@export var effect_script : GDScript

func get_rarity_string(boost_rarity : CharmsManager.Rarities) -> String:
	match boost_rarity:
		CharmsManager.Rarities.COMMON: return "Common"
		CharmsManager.Rarities.RARE: return "Rare"
		CharmsManager.Rarities.EPIC: return "Epic"
		CharmsManager.Rarities.LEGENDARY: return "Legendary"
	return ""
	

func get_shop_color() -> Color:
	return ShopManager.item_colors[rarity]
