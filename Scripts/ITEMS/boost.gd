extends Control


var boost : BoostData
@onready var card: ColorRect = $Confirm/MarginContainer/Card
@onready var boost_name: Label = $Confirm/MarginContainer/Card/PanelColor/Name
@onready var icon: TextureRect = $Confirm/MarginContainer/Card/PanelColor/IconBkg/Icon
@onready var boost_rarity: Label = $Confirm/MarginContainer/Card/PanelColor/Rarity

@onready var confirm: Button = $Confirm

@onready var stat_0: Label = $Confirm/MarginContainer/Card/PanelColor/VBoxContainer/Modification0/Stat0
@onready var bonus_0: Label = $Confirm/MarginContainer/Card/PanelColor/VBoxContainer/Modification0/Bonus0
@onready var new_value_0: Label = $Confirm/MarginContainer/Card/PanelColor/VBoxContainer/Modification0/NewValue0
@onready var stat_1: Label = $Confirm/MarginContainer/Card/PanelColor/VBoxContainer/Modification1/Stat1
@onready var bonus_1: Label = $Confirm/MarginContainer/Card/PanelColor/VBoxContainer/Modification1/Bonus1
@onready var new_value_1: Label = $Confirm/MarginContainer/Card/PanelColor/VBoxContainer/Modification1/NewValue1
@onready var strike_price: Control = $Price/Tags/PriceTag/StrikePrice
@onready var price_cont: HBoxContainer = $Price
@onready var price_tag: Label = $Price/Tags/PriceTag
@onready var discount_tag: Label = $Price/Tags/DiscountTag
@onready var sold_out: ColorRect = $Confirm/MarginContainer/SoldOut
@onready var not_enough_cash_rect: ColorRect = $Confirm/MarginContainer/NotEnoughCash
@onready var arrow: Label = $Confirm/MarginContainer/Card/PanelColor/VBoxContainer/Modification1/arrow

var discounted_price : int

var card_color : Color
var rng : RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	SignalManager.update_fortune.connect(_on_fortune_updated)
	SignalManager.stats_updated.connect((_on_stats_updated))
	rng.randomize()
	

func setup(p_boost : BoostData, p_is_in_shop : bool) -> void : 
	boost = p_boost
	boost.price = rng.randi_range(int(XPManager.current_level + ShopManager.price_levels[boost.rarity] * 0.75 * GameMaster.difficulty_mod),int(XPManager.current_level + ShopManager.price_levels[boost.rarity] * 1.25 * GameMaster.difficulty_mod))
	discounted_price = int(boost.price * ShopManager.discount.get_value())
	price_tag.text = str(boost.price)
	discount_tag.text = str(discounted_price)
	boost_name.text = str(WeaponsManager.Weapons_name.keys()[boost.name])
	icon.texture = boost.icon
	card.color = boost.get_shop_color()
	stat_0.text = boost.get_stat_string(boost.target_stats[0])
	bonus_0.text = get_modifier_sign_string_and_values(boost.target_stats_modifier_types[0],0)
	boost_rarity.text = boost.get_rarity_string(boost.rarity)
	boost_rarity.add_theme_color_override("font_color",boost.get_shop_color())
	boost.is_in_shop = p_is_in_shop

	match boost.target_ressource:
		boost.Target_Ressources.CAR:
			new_value_0.text = str(boost.get_car_stat(boost.target_stats[0],CarManager.selected_car).preview_value(Modifier.new(boost.target_stats_values[0],boost.get_modifier_type(boost.target_stats_modifier_types[0]),"boost applied " + str(WeaponsManager.Weapons_name.keys()[boost.name]))))
		boost.Target_Ressources.WEAPONS:
			new_value_0.text = str(boost.get_weapon_stat(boost.target_stats[0],boost.target_weapon).preview_value(Modifier.new(boost.target_stats_values[0],boost.get_modifier_type(boost.target_stats_modifier_types[0]),"boost applied " +  str(WeaponsManager.Weapons_name.keys()[boost.name]))))
		boost.Target_Ressources.AMMOS:
			new_value_0.text = str(boost.get_weapon_stat(boost.target_stats[0],boost.target_weapon.weapon_ammo_res).preview_value(Modifier.new(boost.target_stats_values[0],boost.get_modifier_type(boost.target_stats_modifier_types[0]),"boost applied " +  str(WeaponsManager.Weapons_name.keys()[boost.name]))))
		
	
	sold_out.hide()
	if boost.is_in_shop:
		price_cont.show()
	else : price_cont.hide()
	
	if boost.target_stats.size()>1:
		stat_1.text = boost.get_stat_string(boost.target_stats[1])
		bonus_1.text = get_modifier_sign_string_and_values(boost.target_stats_modifier_types[1],1)
		match boost.target_ressource:
			boost.Target_Ressources.CAR:
				new_value_1.text = str(boost.get_car_stat(boost.target_stats[1],CarManager.selected_car).preview_value(Modifier.new(boost.target_stats_values[1],boost.get_modifier_type(boost.target_stats_modifier_types[1]),"boost applied " +  str(WeaponsManager.Weapons_name.keys()[boost.name]))))
			boost.Target_Ressources.WEAPONS:
				new_value_1.text = str(boost.get_weapon_stat(boost.target_stats[1],boost.target_weapon).preview_value(Modifier.new(boost.target_stats_values[1],boost.get_modifier_type(boost.target_stats_modifier_types[1]),"boost applied " +  str(WeaponsManager.Weapons_name.keys()[boost.name]))))
			boost.Target_Ressources.AMMOS:
				new_value_1.text = str(boost.get_weapon_stat(boost.target_stats[1],boost.target_weapon.weapon_ammo_res).preview_value(Modifier.new(boost.target_stats_values[1],boost.get_modifier_type(boost.target_stats_modifier_types[1]),"boost applied " +  str(WeaponsManager.Weapons_name.keys()[boost.name]))))
	else :
		stat_1.hide()
		bonus_1.hide()
		new_value_1.hide()

	if ShopManager.apply_discount :
		discount_tag.show()
		strike_price.show()
	else : 
		discount_tag.hide()
		strike_price.hide()
	
	if boost.target_stats.size() <=1:
		arrow.hide()


func get_modifier_sign_string_and_values(type : BoostData.Mod_Type, stat_index : int) -> String:
	match type:
		boost.Mod_Type.FLAT:
			if boost.target_stats_values[stat_index] > 0 :
				return "+ " + str(boost.target_stats_values[stat_index])
			else : 
				return "- " + str(abs(boost.target_stats_values[stat_index]))
		boost.Mod_Type.PERCENT_ADD:
			if boost.target_stats_values[stat_index] > 0 :
				return "+ " + str(boost.target_stats_values[stat_index]) + " %"
			else : 
				return "- " + str(abs(boost.target_stats_values[stat_index])) + " %"
		boost.Mod_Type.PERCENT_MULT:
			if boost.target_stats_values[stat_index] > 0 :
				return "x " + str(boost.target_stats_values[stat_index]) + " %"
			else : 
				return "x - " + str(abs(boost.target_stats_values[stat_index])) + " %"
	return ""


func _on_confirm_pressed() -> void:
	var base_max_life : int = int(CarManager.selected_car.max_life.get_value())
	for selected_boost : Dictionary in boost.get_stats():
		var mod := Modifier.new(selected_boost["value"],selected_boost["type"],"boost applied " +  str(WeaponsManager.Weapons_name.keys()[boost.name]))
		selected_boost["stat"].add_modifier(mod)
		SignalManager.emit_signal("stats_updated")
	var new_max_life : int = int(CarManager.selected_car.max_life.get_value())
	CarManager.selected_car.current_life += new_max_life - base_max_life
	

	if boost.is_in_shop and boost.target_ressource != BoostData.Target_Ressources.CAR :
		if min(boost.price, discounted_price) <= InventoryManager.fortune:
			InventoryManager.fortune -= min(boost.price, discounted_price)
			SignalManager.emit_signal("update_fortune")
			sold_out.show()
			price_cont.hide()
			confirm.disabled = true
		else : 
			not_enough_cash()
	
	elif boost.target_ressource == BoostData.Target_Ressources.CAR : 
		SignalManager.emit_signal("car_level_up_upgrade")


func not_enough_cash()-> void : 
	not_enough_cash_rect.show()
	await get_tree().create_timer(1).timeout
	not_enough_cash_rect.hide()

func _on_fortune_updated() -> void : 
	if boost.price > InventoryManager.fortune:
		price_tag.add_theme_color_override("font_color",Color.RED)

	if discounted_price > InventoryManager.fortune:
		discount_tag.add_theme_color_override("font_color",Color.RED)
	
func _on_stats_updated() -> void : 
	stat_0.text = boost.get_stat_string(boost.target_stats[0])
	bonus_0.text = get_modifier_sign_string_and_values(boost.target_stats_modifier_types[0],0)

	match boost.target_ressource:
		boost.Target_Ressources.CAR:
			new_value_0.text = str(boost.get_car_stat(boost.target_stats[0],CarManager.selected_car).preview_value(Modifier.new(boost.target_stats_values[0],boost.get_modifier_type(boost.target_stats_modifier_types[0]),"boost applied " + str(WeaponsManager.Weapons_name.keys()[boost.name]))))
		boost.Target_Ressources.WEAPONS:
			new_value_0.text = str(boost.get_weapon_stat(boost.target_stats[0],boost.target_weapon).preview_value(Modifier.new(boost.target_stats_values[0],boost.get_modifier_type(boost.target_stats_modifier_types[0]),"boost applied " +  str(WeaponsManager.Weapons_name.keys()[boost.name]))))
		boost.Target_Ressources.AMMOS:
			new_value_0.text = str(boost.get_weapon_stat(boost.target_stats[0],boost.target_weapon.weapon_ammo_res).preview_value(Modifier.new(boost.target_stats_values[0],boost.get_modifier_type(boost.target_stats_modifier_types[0]),"boost applied " +  str(WeaponsManager.Weapons_name.keys()[boost.name]))))
			
	if boost.target_stats.size()>1:
		stat_1.text = boost.get_stat_string(boost.target_stats[1])
		bonus_1.text = get_modifier_sign_string_and_values(boost.target_stats_modifier_types[1],1)
		match boost.target_ressource:
			boost.Target_Ressources.CAR:
				new_value_1.text = str(boost.get_car_stat(boost.target_stats[1],CarManager.selected_car).preview_value(Modifier.new(boost.target_stats_values[1],boost.get_modifier_type(boost.target_stats_modifier_types[1]),"boost applied " +  str(WeaponsManager.Weapons_name.keys()[boost.name]))))
			boost.Target_Ressources.WEAPONS:
				new_value_1.text = str(boost.get_weapon_stat(boost.target_stats[1],boost.target_weapon).preview_value(Modifier.new(boost.target_stats_values[1],boost.get_modifier_type(boost.target_stats_modifier_types[1]),"boost applied " +  str(WeaponsManager.Weapons_name.keys()[boost.name]))))
			boost.Target_Ressources.AMMOS:
				new_value_1.text = str(boost.get_weapon_stat(boost.target_stats[1],boost.target_weapon.weapon_ammo_res).preview_value(Modifier.new(boost.target_stats_values[1],boost.get_modifier_type(boost.target_stats_modifier_types[1]),"boost applied " +  str(WeaponsManager.Weapons_name.keys()[boost.name]))))
	else :
		stat_1.hide()
		bonus_1.hide()
		new_value_1.hide()
