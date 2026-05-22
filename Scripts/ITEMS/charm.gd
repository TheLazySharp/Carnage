extends Control


var boost : BoostData
@onready var card: ColorRect = $Confirm/MarginContainer/Card
@onready var boost_name: Label = $Confirm/MarginContainer/Card/PanelColor/Name
@onready var icon: TextureRect = $Confirm/MarginContainer/Card/PanelColor/IconBkg/Icon
@onready var boost_rarity: Label = $Confirm/MarginContainer/Card/PanelColor/Rarity

@onready var confirm: Button = $Confirm
@onready var description: Label = $Confirm/MarginContainer/Card/PanelColor/Description


@onready var price_cont: HBoxContainer = $Price
@onready var price_tag: Label = $Price/PriceTag
@onready var sold_out: ColorRect = $Confirm/MarginContainer/SoldOut
@onready var not_enough_cash_rect: ColorRect = $Confirm/MarginContainer/NotEnoughCash

var card_color : Color
var rng : RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	SignalManager.update_fortune.connect(_on_fortune_updated)
	rng.randomize()
	

func setup(p_boost : BoostData, p_is_in_shop : bool) -> void : 
	boost = p_boost
	boost.price = rng.randi_range(int(ShopManager.price_levels[boost.rarity]*0.75),int(ShopManager.price_levels[boost.rarity]*1.25))
	price_tag.text = str(boost.price)
	boost_name.text = boost.name
	icon.texture = boost.icon
	card.color = boost.get_shop_color()
	boost_rarity.text = boost.get_rarity_string(boost.rarity)
	boost_rarity.add_theme_color_override("font_color",boost.get_shop_color())
	boost.is_in_shop = p_is_in_shop

	
	sold_out.hide()
	if boost.is_in_shop:
		price_cont.show()
	else : price_cont.hide()




func _on_confirm_pressed() -> void:
	pass

func not_enough_cash()-> void : 
	not_enough_cash_rect.show()
	await get_tree().create_timer(1).timeout
	not_enough_cash_rect.hide()
	
	
func _on_fortune_updated() -> void : 
	if boost.price > InventoryManager.fortune:
		price_tag.add_theme_color_override("font_color",Color.RED)
	
