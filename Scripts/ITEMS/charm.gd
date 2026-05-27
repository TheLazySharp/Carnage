extends Control


var charm : CharmData
@onready var card: ColorRect = $Confirm/MarginContainer/Card
@onready var charm_name: Label = $Confirm/MarginContainer/Card/PanelColor/Name
@onready var icon: TextureRect = $Confirm/MarginContainer/Card/PanelColor/IconBkg/Icon
@onready var charm_rarity: Label = $Confirm/MarginContainer/Card/PanelColor/Rarity

@onready var confirm: Button = $Confirm
@onready var description: Label = $Confirm/MarginContainer/Card/PanelColor/Description

var price_mult : int = 10
@onready var price_cont: HBoxContainer = $Price
@onready var price_tag: Label = $Price/PriceTag
@onready var sold_out: ColorRect = $Confirm/MarginContainer/SoldOut
@onready var not_enough_cash_rect: ColorRect = $Confirm/MarginContainer/NotEnoughCash

var card_color : Color
var rng : RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	SignalManager.update_fortune.connect(_on_fortune_updated)
	rng.randomize()


func setup(p_charm : CharmData, p_is_in_shop : bool) -> void : 
	charm = p_charm
	charm.price = rng.randi_range(int(XPManager.current_level + ShopManager.price_levels[charm.rarity] * 0.75 * GameMaster.difficulty_mod),int(XPManager.current_level + ShopManager.price_levels[charm.rarity] * 1.25 * GameMaster.difficulty_mod)) * price_mult
	price_tag.text = str(charm.price)
	charm_name.text = charm.name
	icon.texture = charm.icon
	card.color = charm.get_shop_color()
	charm_rarity.text = charm.get_rarity_string(charm.rarity)
	charm_rarity.add_theme_color_override("font_color",charm.get_shop_color())
	charm.is_in_shop = p_is_in_shop

	sold_out.hide()
	if charm.is_in_shop:
		price_cont.show()
	else : price_cont.hide()


func _on_confirm_pressed() -> void:
	var effect : CharmEffect = charm.effect_script.new()
	effect.activate()
	CharmsManager.register(charm, effect)

	if charm.is_in_shop:
		if charm.price <= InventoryManager.fortune:
			InventoryManager.fortune -= charm.price
			SignalManager.emit_signal("update_fortune")
			sold_out.show()
			price_cont.hide()
			confirm.disabled = true
		else : 
			not_enough_cash()

	else : 
		ShopManager.boost_shopped += 1
		self.hide()
		if ShopManager.boost_shopped < ShopManager.available_boosts:
			for i : int in range(0,get_parent().get_children().size()-1):
				if get_parent().get_children()[i].visible:
					get_parent().get_child(i).get_child(0).grab_focus()
		
		SignalManager.emit_signal("upgrades_ok")
		get_parent().get_parent().queue_free()


func not_enough_cash()-> void : 
	not_enough_cash_rect.show()
	await get_tree().create_timer(1).timeout
	not_enough_cash_rect.hide()
	
	
func _on_fortune_updated() -> void : 
	if charm.price > InventoryManager.fortune:
		price_tag.add_theme_color_override("font_color",Color.RED)
	
