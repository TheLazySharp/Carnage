extends Control

var boost : BoostData
var player : SurvivorData

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
@onready var new_value_0: StyledLabel = $Confirm/MarginContainer/Card/PanelColor/VBoxContainer/Modification0/NewValue0
@onready var stat_1: Label = $Confirm/MarginContainer/Card/PanelColor/VBoxContainer/Modification1/Stat1
@onready var bonus_1: Label = $Confirm/MarginContainer/Card/PanelColor/VBoxContainer/Modification1/Bonus1
@onready var new_value_1: StyledLabel = $Confirm/MarginContainer/Card/PanelColor/VBoxContainer/Modification1/NewValue1
@onready var strike_price: Control = $Price/Tags/PriceTag/StrikePrice
@onready var price_cont: HBoxContainer = $Price
@onready var price_tag: Label = $Price/Tags/PriceTag
@onready var discount_tag: Label = $Price/Tags/DiscountTag
@onready var sold_out: ColorRect = $Confirm/MarginContainer/SoldOut
@onready var not_enough_cash_rect: ColorRect = $Confirm/MarginContainer/NotEnoughCash
@onready var arrow: Label = $Confirm/MarginContainer/Card/PanelColor/VBoxContainer/Modification1/arrow

var modifications_count : int = 0
var card_color : Color


func _ready() -> void:
	SignalManager.update_fortune.connect(_on_fortune_updated)
	SignalManager.stats_updated.connect((_on_stats_updated))
	player = SurvivorsManager.on_board_survivors[0]


func setup(p_boost : BoostData, p_is_in_shop : bool) -> void:
	boost = p_boost
	modifications_count = get_modifications_count()
	if modifications_count == 0:
		push_warning("BoostData '%s' has no usable modification" % boost.resource_path)
		hide()
		return

	price = randi_range(
		int(XPManager.current_level + ShopManager.boosts_price_levels[boost.rarity] * 0.75 * GameMaster.difficulty_mod),
		int(XPManager.current_level + ShopManager.boosts_price_levels[boost.rarity] * 1.25 * GameMaster.difficulty_mod))
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
	
	if boost.is_car_part():
		_setup_part()


func get_modifier_sign_string_and_values(type : BoostData.Mod_Type, stat_index : int) -> String:
	var value : float = boost.target_stats_values[stat_index]
	var sign_str : String = "+ " if value >= 0.0 else "- "
	match type:
		BoostData.Mod_Type.FLAT:
			return sign_str + str(absf(value))
		BoostData.Mod_Type.PERCENT_ADD:
			# Ratio: 0.15 = +15 %
			return sign_str + str(roundi(absf(value) * 100.0)) + " %"
		BoostData.Mod_Type.PERCENT_MULT:
			# Statistic applies (1 + value): 0.15 = x1.15, -0.1 = x0.9
			return "x " + str(snappedf(1.0 + value, 0.01))
	return ""


func _on_confirm_pressed() -> void:
	if boost.is_car_part():
		_confirm_part()
		return
		
	var is_purchase : bool = is_in_shop and boost.target_ressource != BoostData.Target_Ressources.CAR
	var final_price : int = mini(price, discounted_price)
	
	# Check the wallet BEFORE applying anything
	if is_purchase and final_price > InventoryManager.blood_tank_q:
		not_enough_cash()
		return

	var base_max_life : int = int(CarManager.selected_car.max_life.get_value())
	for selected_boost : Dictionary in boost.get_stats():
		var mod := Modifier.new(selected_boost["value"], selected_boost["type"], "boost applied " + InventoryManager.get_boost_name(boost))
		selected_boost["stat"].add_modifier(mod)
	var new_max_life : int = int(CarManager.selected_car.max_life.get_value())
	CarManager.selected_car.current_life += new_max_life - base_max_life
	SignalManager.stats_updated.emit()   # emitted once, not inside the loop

	if is_purchase and final_price <= InventoryManager.blood_tank_q:
		InventoryManager.blood_tank_q -= final_price
		SignalManager.emit_signal("update_fortune")
		sold_out.show()
		price_cont.hide()
		confirm.disabled = true
	

func not_enough_cash()-> void : 
	not_enough_cash_rect.show()
	await get_tree().create_timer(1).timeout
	not_enough_cash_rect.hide()


func _on_fortune_updated() -> void : 
	if price > InventoryManager.blood_tank_q:
		price_tag.add_theme_color_override("font_color",Color.RED)

	if discounted_price > InventoryManager.blood_tank_q:
		discount_tag.add_theme_color_override("font_color",Color.RED)
	
	if boost == null:
		return


func _on_stats_updated() -> void:
	if boost == null:
		return
	refresh_modifications()

func _on_confirm_focus_entered() -> void:
	SignalManager.emit_signal("focused_entered",self.get_node("Confirm"))


func _on_confirm_focus_exited() -> void:
	pass # Replace with function body.

# Number of complete modification lines: the three parallel arrays must all be filled.
# Prevents out of bounds access when a BoostData resource is badly configured.
func get_modifications_count() -> int:
	# Car part: one line per target stat, its bonus comes from the level (two lines on the card at most)
	if boost.is_car_part():
		return mini(boost.target_stats.size(), 2)
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

func refresh_modification_line(stat_index : int, stat_label : Label, bonus_label : Label, value_label : StyledLabel) -> void:
	stat_label.text = boost.get_stat_string(boost.target_stats[stat_index])
	bonus_label.text = _get_bonus_string(stat_index)

	var target_stat : Statistic = get_target_stat(stat_index)
	if target_stat == null:
		value_label.text = "-"
		value_label.reset_color()
		return

	var current_value : float = target_stat.get_value()
	var new_value : float = target_stat.preview_value(_get_preview_modifier(stat_index))
	value_label.text = str(snappedf(new_value, 0.01))

	# XOR: a drop is a downgrade, unless lowering this stat is an improvement
	var is_downgrade : bool = not is_equal_approx(new_value, current_value) \
		and (new_value < current_value) != BoostData.is_lower_better(boost.target_stats[stat_index])
	if is_downgrade:
		value_label.set_color(Color.RED)
	else:
		value_label.set_color(Color.GREEN)

func refresh_modifications() -> void:
	refresh_modification_line(0, stat_0, bonus_0, new_value_0)
	var has_second : bool = modifications_count > 1
	stat_1.visible = has_second
	bonus_1.visible = has_second
	new_value_1.visible = has_second
	arrow.visible = has_second
	if has_second:
		refresh_modification_line(1, stat_1, bonus_1, new_value_1)

# ---------------- CAR PARTS ----------------

## Car part card: level instead of rarity, greyed out and not selectable once maxed
func _setup_part() -> void:
	var level : int = CarManager.selected_car.get_part_level(boost.car_part)
	var maxed : bool = level >= boost.get_max_level()
	boost_name.text = tr(boost.name)
	boost_rarity.add_theme_color_override("font_color", Color.WHITE)
	if maxed:
		boost_rarity.text = tr("PART_MAX")
		confirm.disabled = true
		confirm.focus_mode = Control.FOCUS_NONE
		modulate = Color(1.0, 1.0, 1.0, 0.5)
	else:
		boost_rarity.text = "%s %d > %d" % [tr("PART_LEVEL"), level, level + 1]


func _confirm_part() -> void:
	var car : CarData = CarManager.selected_car
	var base_max_life : int = int(car.max_life.get_value())
	if !car.upgrade_part(boost):
		return
	car.current_life += int(car.max_life.get_value()) - base_max_life
	SignalManager.stats_updated.emit()
	SignalManager.car_level_up_upgrade.emit()


## Modifier shown in the preview: the next level of a part, or the boost's own values
func _get_preview_modifier(stat_index : int) -> Modifier:
	if boost.is_car_part():
		return boost.make_part_modifier(CarManager.selected_car.get_part_level(boost.car_part))
	return Modifier.new(
		boost.target_stats_values[stat_index],
		boost.get_modifier_type(boost.target_stats_modifier_types[stat_index]),
		"boost applied " + InventoryManager.get_boost_name(boost))


func _get_bonus_string(stat_index : int) -> String:
	if boost.is_car_part():
		var bonus : float = boost.get_next_bonus(CarManager.selected_car.get_part_level(boost.car_part))
		return "-" if bonus <= 0.0 else "+ %d %%" % roundi(bonus * 100.0)
	return get_modifier_sign_string_and_values(boost.target_stats_modifier_types[stat_index], stat_index)
