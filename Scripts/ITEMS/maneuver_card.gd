extends Control
class_name ShopManeuverCard
## Maneuver card of the shop: name, icon, current level (NEW / level / MAX) and price.
## Bought by the shop through Confirm; the description is shown in the shop's DescPanel

@onready var confirm : Button = $Confirm
@onready var maneuver_name : Label = $Confirm/MarginContainer/Card/PanelColor/Name
@onready var level_label : Label = $Confirm/MarginContainer/Card/PanelColor/Level
@onready var icon : TextureRect = $Confirm/MarginContainer/Card/PanelColor/IconBkg/Icon
@onready var sold_out : ColorRect = $Confirm/MarginContainer/SoldOut
@onready var not_enough_cash_rect : ColorRect = $Confirm/MarginContainer/NotEnoughCash

@onready var price_cont : HBoxContainer = $Price
@onready var price_tag : Label = $Price/PriceTags/Price/PriceTag
@onready var strike_price : Control = $Price/PriceTags/Price/PriceTag/StrikePrice
@onready var discount_cont : HBoxContainer = $Price/PriceTags/Discount
@onready var discount_tag : Label = $Price/PriceTags/Discount/DiscountTag


func setup(data : ManeuverData) -> void:
	maneuver_name.text = tr(data.name_key)
	icon.texture = data.icon
	sold_out.hide()
	not_enough_cash_rect.hide()


func refresh(level_text : String, price : int, discounted_price : int, affordable : bool, sold : bool) -> void:
	level_label.text = level_text
	sold_out.visible = sold
	price_cont.visible = !sold
	confirm.disabled = sold
	price_tag.text = str(price)
	discount_tag.text = str(discounted_price)
	discount_cont.visible = ShopManager.apply_discount
	strike_price.visible = ShopManager.apply_discount
	# Red when the blood bank no longer covers it
	for tag : Label in [price_tag, discount_tag]:
		if affordable:
			tag.remove_theme_color_override("font_color")
		else:
			tag.add_theme_color_override("font_color", Color.RED)


## Short flash. A tween rather than an await: it dies with the card if a reroll frees it
func not_enough_cash() -> void:
	not_enough_cash_rect.show()
	var tween : Tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(not_enough_cash_rect.hide)
