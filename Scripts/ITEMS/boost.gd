extends Control

var boost : BoostData
var price : int = 0
var discounted_price : int = 0
var is_in_shop : bool = false

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

var modifications_count : int = 0
var card_color : Color
#var rng : RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	SignalManager.update_fortune.connect(_on_fortune_updated)
	SignalManager.stats_updated.connect((_on_stats_updated))
	#rng.randomize()
	

func setup(p_boost : BoostData, p_is_in_shop : bool) -> void:
	boost = p_boost
	modifications_count = get_modifications_count()
	if modifications_count == 0:
		push_warning("BoostData '%s' has no usable modification" % boost.resource_path)
		hide()
		return

	price = randi_range(
		int(XPManager.current_level + ShopManager.price_levels[boost.rarity] * 0.75 * GameMaster.difficulty_mod),
		int(XPManager.current_level + ShopManager.price_levels[boost.rarity] * 1.25 * GameMaster.difficulty_mod))
	discounted_price = int(price * ShopManager.discount.get_value())
	price_tag.text = str(price)
	discount_tag.text = str(discounted_price)
	is_in_shop = p_is_in_shop

	boost_name.text = InventoryManager.get_boost_name(boost)
	icon.texture = boost.icon
	card.color = boost.get_shop_color()
	boost_rarity.text = boost.get_rarity_string(boost.rarity)
	boost_rarity.add_theme_color_override("font_color", boost.get_shop_color())

	refresh_modifications()

	sold_out.hide()
	price_cont.visible = is_in_shop
	discount_tag.visible = ShopManager.apply_discount
	strike_price.visible = ShopManager.apply_discount


#func setup(p_boost : BoostData, p_is_in_shop : bool) -> void : 
	#boost = p_boost
	#modifications_count = get_modifications_count()
	#if modifications_count == 0:
		#push_warning("BoostData '%s' has no usable modification" % boost.resource_path)
		#hide()
		#return
	#price = randi_range(
		#int(XPManager.current_level + ShopManager.price_levels[boost.rarity] * 0.75 * GameMaster.difficulty_mod),
		#int(XPManager.current_level + ShopManager.price_levels[boost.rarity] * 1.25 * GameMaster.difficulty_mod))
	#discounted_price = int(price * ShopManager.discount.get_value())
	#price_tag.text = str(price)
	#discount_tag.text = str(discounted_price)
	#boost_name.text = InventoryManager.get_boost_name(boost)
	#icon.texture = boost.icon
	#card.color = boost.get_shop_color()
	#stat_0.text = boost.get_stat_string(boost.target_stats[0])
	#bonus_0.text = get_modifier_sign_string_and_values(boost.target_stats_modifier_types[0],0)
	#boost_rarity.text = boost.get_rarity_string(boost.rarity)
	#boost_rarity.add_theme_color_override("font_color",boost.get_shop_color())
	#is_in_shop = p_is_in_shop
#
	#match boost.target_ressource:
		#boost.Target_Ressources.CAR:
			#new_value_0.text = str(boost.get_car_stat(boost.target_stats[0],CarManager.selected_car).preview_value(Modifier.new(boost.target_stats_values[0],boost.get_modifier_type(boost.target_stats_modifier_types[0]),"boost applied " + InventoryManager.get_boost_name(boost))))
		#boost.Target_Ressources.WEAPONS:
			#new_value_0.text = str(boost.get_weapon_stat(boost.target_stats[0],boost.target_weapon).preview_value(Modifier.new(boost.target_stats_values[0],boost.get_modifier_type(boost.target_stats_modifier_types[0]),"boost applied " +  InventoryManager.get_boost_name(boost))))
		#boost.Target_Ressources.AMMOS:
			#new_value_0.text = str(boost.get_weapon_stat(boost.target_stats[0],boost.target_weapon.weapon_ammo_res).preview_value(Modifier.new(boost.target_stats_values[0],boost.get_modifier_type(boost.target_stats_modifier_types[0]),"boost applied " +  InventoryManager.get_boost_name(boost))))
		#
	#
	#sold_out.hide()
	#if is_in_shop:
		#price_cont.show()
	#else : price_cont.hide()
	#
	#if modifications_count > 1:
		#stat_1.text = boost.get_stat_string(boost.target_stats[1])
		#bonus_1.text = get_modifier_sign_string_and_values(boost.target_stats_modifier_types[1],1)
		#match boost.target_ressource:
			#boost.Target_Ressources.CAR:
				#new_value_1.text = str(boost.get_car_stat(boost.target_stats[1],CarManager.selected_car).preview_value(Modifier.new(boost.target_stats_values[1],boost.get_modifier_type(boost.target_stats_modifier_types[1]),"boost applied " +  InventoryManager.get_boost_name(boost))))
			#boost.Target_Ressources.WEAPONS:
				#new_value_1.text = str(boost.get_weapon_stat(boost.target_stats[1],boost.target_weapon).preview_value(Modifier.new(boost.target_stats_values[1],boost.get_modifier_type(boost.target_stats_modifier_types[1]),"boost applied " +  InventoryManager.get_boost_name(boost))))
			#boost.Target_Ressources.AMMOS:
				#new_value_1.text = str(boost.get_weapon_stat(boost.target_stats[1],boost.target_weapon.weapon_ammo_res).preview_value(Modifier.new(boost.target_stats_values[1],boost.get_modifier_type(boost.target_stats_modifier_types[1]),"boost applied " +  InventoryManager.get_boost_name(boost))))
	#else :
		#stat_1.hide()
		#bonus_1.hide()
		#new_value_1.hide()
#
	#if ShopManager.apply_discount :
		#discount_tag.show()
		#strike_price.show()
	#else : 
		#discount_tag.hide()
		#strike_price.hide()
	#
	#if modifications_count <= 1:
		#arrow.hide()


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
	var is_purchase : bool = is_in_shop and boost.target_ressource != BoostData.Target_Ressources.CAR
	var final_price : int = mini(price, discounted_price)
	# Check the wallet BEFORE applying anything
	if is_purchase and final_price > InventoryManager.fortune:
		not_enough_cash()
		return

	var base_max_life : int = int(CarManager.selected_car.max_life.get_value())
	for selected_boost : Dictionary in boost.get_stats():
		var mod := Modifier.new(selected_boost["value"], selected_boost["type"], "boost applied " + InventoryManager.get_boost_name(boost))
		selected_boost["stat"].add_modifier(mod)
	var new_max_life : int = int(CarManager.selected_car.max_life.get_value())
	CarManager.selected_car.current_life += new_max_life - base_max_life
	SignalManager.stats_updated.emit()   # emitted once, not inside the loop

	if is_purchase:
		InventoryManager.fortune -= final_price
		SignalManager.update_fortune.emit()
		sold_out.show()
		price_cont.hide()
		confirm.disabled = true
	elif boost.target_ressource == BoostData.Target_Ressources.CAR:
		SignalManager.car_level_up_upgrade.emit()


func not_enough_cash()-> void : 
	not_enough_cash_rect.show()
	await get_tree().create_timer(1).timeout
	not_enough_cash_rect.hide()

func _on_fortune_updated() -> void : 
	if price > InventoryManager.fortune:
		price_tag.add_theme_color_override("font_color",Color.RED)

	if discounted_price > InventoryManager.fortune:
		discount_tag.add_theme_color_override("font_color",Color.RED)
	
	if boost == null:
		return


func _on_stats_updated() -> void:
	if boost == null:
		return
	refresh_modifications()

#func _on_stats_updated() -> void : 
	#stat_0.text = boost.get_stat_string(boost.target_stats[0])
	#bonus_0.text = get_modifier_sign_string_and_values(boost.target_stats_modifier_types[0],0)
#
	#match boost.target_ressource:
		#boost.Target_Ressources.CAR:
			#new_value_0.text = str(boost.get_car_stat(boost.target_stats[0],CarManager.selected_car).preview_value(Modifier.new(boost.target_stats_values[0],boost.get_modifier_type(boost.target_stats_modifier_types[0]),"boost applied " + InventoryManager.get_boost_name(boost))))
		#boost.Target_Ressources.WEAPONS:
			#new_value_0.text = str(boost.get_weapon_stat(boost.target_stats[0],boost.target_weapon).preview_value(Modifier.new(boost.target_stats_values[0],boost.get_modifier_type(boost.target_stats_modifier_types[0]),"boost applied " +  InventoryManager.get_boost_name(boost))))
		#boost.Target_Ressources.AMMOS:
			#new_value_0.text = str(boost.get_weapon_stat(boost.target_stats[0],boost.target_weapon.weapon_ammo_res).preview_value(Modifier.new(boost.target_stats_values[0],boost.get_modifier_type(boost.target_stats_modifier_types[0]),"boost applied " +  InventoryManager.get_boost_name(boost))))
			#
	#if modifications_count > 1:
		#stat_1.text = boost.get_stat_string(boost.target_stats[1])
		#bonus_1.text = get_modifier_sign_string_and_values(boost.target_stats_modifier_types[1],1)
		#match boost.target_ressource:
			#boost.Target_Ressources.CAR:
				#new_value_1.text = str(boost.get_car_stat(boost.target_stats[1],CarManager.selected_car).preview_value(Modifier.new(boost.target_stats_values[1],boost.get_modifier_type(boost.target_stats_modifier_types[1]),"boost applied " +  InventoryManager.get_boost_name(boost))))
			#boost.Target_Ressources.WEAPONS:
				#new_value_1.text = str(boost.get_weapon_stat(boost.target_stats[1],boost.target_weapon).preview_value(Modifier.new(boost.target_stats_values[1],boost.get_modifier_type(boost.target_stats_modifier_types[1]),"boost applied " +  InventoryManager.get_boost_name(boost))))
			#boost.Target_Ressources.AMMOS:
				#new_value_1.text = str(boost.get_weapon_stat(boost.target_stats[1],boost.target_weapon.weapon_ammo_res).preview_value(Modifier.new(boost.target_stats_values[1],boost.get_modifier_type(boost.target_stats_modifier_types[1]),"boost applied " +  InventoryManager.get_boost_name(boost))))
	#else :
		#stat_1.hide()
		#bonus_1.hide()
		#new_value_1.hide()
	#
	#if boost == null:
		#return

func _on_confirm_focus_entered() -> void:
	SignalManager.emit_signal("focused_entered",self.get_node("Confirm"))


func _on_confirm_focus_exited() -> void:
	pass # Replace with function body.

# Number of complete modification lines: the three parallel arrays must all be filled.
# Prevents out of bounds access when a BoostData resource is badly configured.
func get_modifications_count() -> int:
	var stats_count : int = boost.target_stats.size()
	var count : int = mini(stats_count, mini(boost.target_stats_values.size(), boost.target_stats_modifier_types.size()))
	if count != stats_count:
		push_warning("BoostData '%s': array size mismatch (stats:%d values:%d types:%d)" % [
			boost.resource_path, stats_count,
			boost.target_stats_values.size(), boost.target_stats_modifier_types.size()])
	return count



# Returns the Stat resource targeted by the modification at stat_index
func get_target_stat(stat_index : int) -> Statistic:
	match boost.target_ressource:
		BoostData.Target_Ressources.CAR:
			return boost.get_car_stat(boost.target_stats[stat_index], CarManager.selected_car)
		BoostData.Target_Ressources.WEAPONS:
			return boost.get_weapon_stat(boost.target_stats[stat_index], boost.target_weapon)
		BoostData.Target_Ressources.AMMOS:
			return boost.get_weapon_stat(boost.target_stats[stat_index], boost.target_weapon.weapon_ammo_res)
	return null


# Fills one modification line: stat name, bonus, previewed new value
func refresh_modification_line(stat_index : int, stat_label : Label, bonus_label : Label, value_label : Label) -> void:
	stat_label.text = boost.get_stat_string(boost.target_stats[stat_index])
	bonus_label.text = get_modifier_sign_string_and_values(boost.target_stats_modifier_types[stat_index], stat_index)
	var target_stat : Statistic = get_target_stat(stat_index)
	if target_stat == null:
		value_label.text = "-"
		return
	var preview_mod := Modifier.new(
		boost.target_stats_values[stat_index],
		boost.get_modifier_type(boost.target_stats_modifier_types[stat_index]),
		"boost applied " + InventoryManager.get_boost_name(boost))
	value_label.text = str(target_stat.preview_value(preview_mod))


# Refreshes both modification lines and their visibility
func refresh_modifications() -> void:
	refresh_modification_line(0, stat_0, bonus_0, new_value_0)
	var has_second : bool = modifications_count > 1
	stat_1.visible = has_second
	bonus_1.visible = has_second
	new_value_1.visible = has_second
	arrow.visible = has_second
	if has_second:
		refresh_modification_line(1, stat_1, bonus_1, new_value_1)
