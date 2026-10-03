extends Control


var weapon : WeaponData
var player : SurvivorData
@onready var card: ColorRect = $Confirm/MarginContainer/Card
@onready var weapon_name: Label = $Confirm/MarginContainer/Card/PanelColor/Name
@onready var icon: TextureRect = $Confirm/MarginContainer/Card/PanelColor/IconBkg/Icon

@onready var confirm: Button = $Confirm
@onready var description: Label = $Confirm/MarginContainer/Card/PanelColor/Description

var price_mult : int = 10
@onready var price_cont: HBoxContainer = $Price
@onready var price_tag: Label = $Price/PriceTags/PriceTag
@onready var discount_tag: Label = $Price/PriceTags/DiscountTag
@onready var strike_price: Control = $Price/PriceTags/PriceTag/StrikePrice


@onready var sold_out: ColorRect = $Confirm/MarginContainer/SoldOut
@onready var not_enough_cash_rect: ColorRect = $Confirm/MarginContainer/NotEnoughCash

var price : int = 20
var is_in_shop : bool = false

var card_color : Color
var rng : RandomNumberGenerator = RandomNumberGenerator.new()
var discounted_price : int

func _ready() -> void:
	SignalManager.pit_choice.connect(_on_pit_choice)
	player = SurvivorsManager.on_board_survivors[0]
	rng.randomize()


func setup(p_weapon : WeaponData, p_is_in_shop : bool) -> void : 
	weapon = p_weapon
	is_in_shop = p_is_in_shop
	weapon_name.text = InventoryManager.get_weapon_name(p_weapon)
	icon.texture = weapon.weapon_icon
	description.text = weapon.description
	sold_out.hide()
	if p_is_in_shop:
		price_tag.text = str(price)
		discounted_price = int(price * ShopManager.discount.get_value())
		discount_tag.text = str(discounted_price)
		price_cont.show()
	else : price_cont.hide()
	
	if ShopManager.apply_discount :
		discount_tag.show()
		strike_price.show()
	else : 
		discount_tag.hide()
		strike_price.hide()
		

func _on_confirm_pressed() -> void:
	if is_in_shop:
		var blood_cost : int = min(price, discounted_price)
		if blood_cost <= player.current_life:
			WeaponsManager.equip_weapon(weapon)
			SignalManager.emit_signal("survivor_blood_consummed",blood_cost)
			SignalManager.emit_signal("blood_payment",blood_cost)
			SignalManager.emit_signal("pit_choice")
			sold_out.show()
			price_cont.hide()
			confirm.disabled = true
		else : 
			not_enough_cash()


func not_enough_cash()-> void : 
	not_enough_cash_rect.show()
	await get_tree().create_timer(1).timeout
	not_enough_cash_rect.hide()
	
	
func _on_pit_choice() -> void : 
	if price > player.current_life:
		price_tag.add_theme_color_override("font_color",Color.RED)
	if discounted_price > InventoryManager.fortune:
		discount_tag.add_theme_color_override("font_color",Color.RED)
