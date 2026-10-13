extends Control

@export var card_color : Color = Color(0.55, 0.1, 0.1)
@export var price_variation : float = 0.25  # random +/- share around the base price, like the charms

@onready var card : ColorRect = $Confirm/MarginContainer/Card
@onready var maneuver_name : Label = $Confirm/MarginContainer/Card/PanelColor/Name
@onready var icon : TextureRect = $Confirm/MarginContainer/Card/PanelColor/IconBkg/Icon
@onready var description : Label = $Confirm/MarginContainer/Card/PanelColor/Description
@onready var confirm : Button = $Confirm
@onready var sold_out : ColorRect = $Confirm/MarginContainer/SoldOut
@onready var not_enough_cash_rect : ColorRect = $Confirm/MarginContainer/NotEnoughCash
@onready var price_cont : HBoxContainer = $Price
@onready var price_tag : Label = $Price/PriceTags/PriceTag
@onready var discount_tag : Label = $Price/PriceTags/DiscountTag
@onready var strike_price : Control = $Price/PriceTags/PriceTag/StrikePrice

var maneuver : ManeuverData = null
var shop_price : int = 0
var discounted_price : int = 0
var not_enough_cash_left : float = 0.0


func _ready() -> void:
	SignalManager.update_fortune.connect(_on_fortune_updated)
	set_process(false)


func setup(p_maneuver : ManeuverData) -> void:
	maneuver = p_maneuver
	maneuver_name.text = tr(maneuver.name_key)
	description.text = tr(maneuver.description_key)
	icon.texture = maneuver.icon
	card.color = card_color
	sold_out.hide()
	not_enough_cash_rect.hide()

	var base : float = maneuver.base_price * GameMaster.difficulty_mod
	shop_price = roundi(randf_range(base * (1.0 - price_variation), base * (1.0 + price_variation)))
	discounted_price = int(shop_price * ShopManager.discount.get_value())
	price_tag.text = str(shop_price)
	discount_tag.text = str(discounted_price)
	discount_tag.visible = ShopManager.apply_discount
	strike_price.visible = ShopManager.apply_discount
	_on_fortune_updated()


func _on_confirm_pressed() -> void:
	var final_price : int = mini(shop_price, discounted_price)
	if final_price > InventoryManager.blood_tank_q:
		_show_not_enough_cash()
		return
	InventoryManager.blood_tank_q -= final_price
	BloodBars.update_blood_tank()
	SignalManager.emit_signal("update_fortune")
	LoadoutManager.unlock(maneuver.maneuver_type)
	sold_out.show()
	price_cont.hide()
	confirm.disabled = true


func _show_not_enough_cash() -> void:
	not_enough_cash_rect.show()
	not_enough_cash_left = 1.0
	set_process(true)


func _process(delta : float) -> void:
	not_enough_cash_left -= delta
	if not_enough_cash_left <= 0.0:
		not_enough_cash_rect.hide()
		set_process(false)


func _on_fortune_updated() -> void:
	var too_expensive : bool = mini(shop_price, discounted_price) > InventoryManager.blood_tank_q
	for tag : Label in [price_tag, discount_tag]:
		if too_expensive:
			tag.add_theme_color_override("font_color", Color.RED)
		else:
			tag.remove_theme_color_override("font_color")
