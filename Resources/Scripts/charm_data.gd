extends Resource
class_name CharmData

@export var name: ShopManager.Items_Name
@export var icon: Texture2D
@export var description: String
@export var rarity: InventoryManager.Rarities
var price: int
var is_in_shop : bool = false
@export var p_value : float
@export var p_value_descr : String


@export var effect_script : GDScript

func get_rarity_string(boost_rarity : InventoryManager.Rarities) -> String:
	match boost_rarity:
		InventoryManager.Rarities.COMMON: return "Common"
		InventoryManager.Rarities.RARE: return "Rare"
		InventoryManager.Rarities.EPIC: return "Epic"
		InventoryManager.Rarities.LEGENDARY: return "Legendary"
	return ""
	

func get_shop_color() -> Color:
	return ShopManager.item_colors[rarity]
