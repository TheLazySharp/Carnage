extends Control

@export var card_color : Color = Color(0.55, 0.1, 0.1)
@export var price_variation : float = 0.25  # random +/- share around the base price, like the charms
@export var upgrade_price_step : float = 0.5  # price x(1 + step x current level): new 1x, lv1>2 1.5x ... lv4>5 3x

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
var is_upgrade : bool = false  # owned: the card sells the next level
var shop_price : int = 0
var discounted_price : int = 0
var not_enough_cash_left : float = 0.0


func _ready() -> void:
	SignalManager.update_fortune.connect(_on_fortune_updated)
	set_process(false)


func setup(p_maneuver : ManeuverData) -> void:
	maneuver = p_maneuver
	var level : int = LoadoutManager.get_maneuver_level(maneuver.maneuver_type)
	is_upgrade = level > 0
	maneuver_name.text = tr(maneuver.name_key)
	# First line: new maneuver, or the level it goes to
	var level_line : String = tr("MANEUVER_NEW") if !is_upgrade else "%s %d > %d" % [tr("PART_LEVEL"), level, level + 1]
	description.text = level_line + "\n" + tr(maneuver.description_key)
	icon.texture = maneuver.icon
	card.color = card_color
	sold_out.hide()
	not_enough_cash_rect.hide()

	# Same price for the whole offer: rolled once, then read back on every visit
	if ShopManager.current_maneuver_prices.has(maneuver):
		shop_price = ShopManager.current_maneuver_prices[maneuver]
	else:
		var base : float = maneuver.base_price * GameMaster.difficulty_mod * (1.0 + upgrade_price_step * level)
		shop_price = roundi(randf_range(base * (1.0 - price_variation), base * (1.0 + price_variation)))
		ShopManager.current_maneuver_prices[maneuver] = shop_price
	discounted_price = int(shop_price * ShopManager.discount.get_value())
	price_tag.text = str(shop_price)
	discount_tag.text = str(discounted_price)
	discount_tag.visible = ShopManager.apply_discount
	strike_price.visible = ShopManager.apply_discount
	_on_fortune_updated()

	# Bought during an earlier visit of this offer
	if ShopManager.current_maneuvers_sold.has(maneuver):
		sold_out.show()
		price_cont.hide()
		confirm.disabled = true


func _on_confirm_pressed() -> void:
	var final_price : int = mini(shop_price, discounted_price)
	if final_price > InventoryManager.blood_tank_q:
		_show_not_enough_cash()
		return
	InventoryManager.blood_tank_q -= final_price
	BloodBars.update_blood_tank()
	SignalManager.emit_signal("update_fortune")
	if is_upgrade:
		LoadoutManager.upgrade(maneuver.maneuver_type)
	else:
		LoadoutManager.unlock(maneuver.maneuver_type)
	ShopManager.current_maneuvers_sold.append(maneuver)
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
