extends Control
## Shop: 3 random charms and 3 random maneuver cards (new ones to unlock, owned ones to upgrade).
## Navigation by code over zones: charms, maneuvers, repair / reroll / back buttons.
## The offer (cards, prices, sold cards) is kept until the next raid or a reroll

enum Zone { CHARMS, MANEUVERS, REPAIR, REROLL, BACK }
# Results of _move_in_cards() when the move leaves the card grid
const EXIT_UP : int = -1
const EXIT_DOWN : int = -2
const EXIT_LEFT : int = -3
const EXIT_RIGHT : int = -4

var player : SurvivorData

@onready var charm_container: GridContainer = $CharmContainer

@export var boost_scene : PackedScene
@export var charm_scene : PackedScene
@onready var cash_register: AudioStreamPlayer = $Sfx/CashRegister
@onready var back: Button = $VBoxContainer/Back
@onready var shop: Control = $"."
@onready var reroll_button : Button = $Buttons/Reroll
@onready var reroll_cost_label: Label = $Buttons/Reroll/Cost
@onready var reroll_label: Label = $Buttons/Reroll/Reroll
@onready var repair_button: Button = $Buttons/RepairButton

@export_group("Maneuvers")
@export var maneuver_container : GridContainer   # cards of the maneuver offer
@export var maneuver_card_scene : PackedScene    # ShopManeuverCard
@export var maneuver_desc_label : Label          # ManeuverDesc
@export var desc_name_label : Label              # DescPanel/Name
@export var desc_icon : TextureRect              # DescPanel/IconBkg/Icon
@export var price_variation : float = 0.25       # random +/- share around the base price
@export var upgrade_price_step : float = 0.5     # price x(1 + step x purchase): unlock 1x, lv1 1.5x ... lv5 3.5x

@export_group("Inventory popup")
@export var inventory_popup : Control           # "slots full" message, hides by itself
@export var inventory_popup_label : Label
@export var inventory_popup_duration : float = 2.5


var nb_ammo : int = 2
var nb_weapon : int = 2
var nb_charm : int = 3
var nb_maneuver : int = 3

var font_button : Array = FontManager.FONTS[FontManager.types.BUTTON]
var font_button_focus : Array = FontManager.FONTS[FontManager.types.BUTTON_FOCUS]
var font_button_pressed : Array = FontManager.FONTS[FontManager.types.BUTTON_PRESSED]
var font_button_hover : Array = FontManager.FONTS[FontManager.types.BUTTON_HOVER]

var items_ready : bool = false

# ---- Offer cards ----
var charm_buttons : Array[Button] = []      # Confirm button of each charm card
var maneuver_cards : Array[ShopManeuverCard] = []
var maneuver_buttons : Array[Button] = []   # Confirm button of each maneuver card

# ---- Navigation ----
var zone : Zone = Zone.REPAIR
var charm_index : int = 0
var maneuver_index : int = 0
var popup_time_left : float = 0.0


func _ready() -> void:
	player = SurvivorsManager.on_board_survivors[0]

	SignalManager.update_fortune.connect(_on_item_baught)
	SignalManager.charm_stored.connect(_on_charm_stored)
	if inventory_popup != null:
		inventory_popup.hide()

	if ShopManager.free_rerolls_left > 0:
		reroll_cost_label.text = "FREE"
	else :
		reroll_cost_label.text = str(ShopManager.get_reroll_cost())

	#REROLL BUTTON
	reroll_button.add_theme_font_override("font",font_button[0])
	reroll_button.add_theme_font_size_override("font_size",font_button[1])
	reroll_button.add_theme_color_override("font_color",font_button[2])
	reroll_button.add_theme_color_override("font_focus_color",font_button_focus[2])
	reroll_button.add_theme_color_override("font_pressed_color",font_button_pressed[2])
	reroll_button.add_theme_color_override("font_hover_color",font_button_hover[2])

	var new_stylebox : StyleBox = reroll_button.get_theme_stylebox("focus")
	new_stylebox.border_color = FontManager.dark_yellow
	reroll_button.add_theme_stylebox_override("focus",new_stylebox)

	# A button selected with the mouse: the navigation continues from it
	repair_button.focus_entered.connect(_on_button_focus_entered.bind(Zone.REPAIR))
	reroll_button.focus_entered.connect(_on_button_focus_entered.bind(Zone.REROLL))
	back.focus_entered.connect(_on_button_focus_entered.bind(Zone.BACK))

	if ShopManager.offer_ready:
		_build_offer()
	else:
		reroll()
	update_reroll_button()

	repair_button.grab_focus()
	_refresh_details()

	SignalManager.emit_signal("shop_entered")
	BloodBars.show()

	GuideManager.play(&"shop", [
		{"text": "GUIDE_SHOP_REPAIR", "target": repair_button},
		{"text": "GUIDE_SHOP_CHARMS", "target": charm_container},
		{"text": "GUIDE_SHOP_MANEUVERS", "target": maneuver_container},
		{"text": "GUIDE_SHOP_COMBO", "target": maneuver_container},
	])

# ---------------- INPUT ----------------

## Navigation polled: one press per push of the stick (no repeat from analog motion events)
func _process(_delta : float) -> void:
	# Inventory popup: hides by itself
	if popup_time_left > 0.0:
		popup_time_left -= _delta
		if popup_time_left <= 0.0:
			inventory_popup.hide()
	if Input.is_action_just_pressed("ui_up"):
		_move_focus(0, -1)
	elif Input.is_action_just_pressed("ui_down"):
		_move_focus(0, 1)
	elif Input.is_action_just_pressed("ui_left"):
		_move_focus(-1, 0)
	elif Input.is_action_just_pressed("ui_right"):
		_move_focus(1, 0)


func _input(event: InputEvent) -> void:
	# Mouse: handled by the cards and buttons themselves
	if event is InputEventMouse:
		return
	# Directions are handled in _process: Godot's own focus moves would fight it
	if event.is_action("ui_up") or event.is_action("ui_down") or event.is_action("ui_left") or event.is_action("ui_right"):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("confirm"):
		back.grab_focus()
	if event.is_action_pressed("cancel"):
		back.grab_focus()
	# Cards and buttons: ui_accept presses the focused button (Godot)


func _move_focus(dx : int, dy : int) -> void:
	match zone:
		Zone.CHARMS, Zone.MANEUVERS:
			_move_in_zone(zone, dx, dy)
		Zone.REPAIR:
			if dy < 0:
				_set_zone(Zone.REROLL)
			elif dy > 0:
				_enter_from_repair()
		Zone.REROLL:
			if dy > 0:
				_set_zone(Zone.REPAIR)
		Zone.BACK:
			if dy < 0:
				_enter_from_back()


func _move_in_zone(card_zone : Zone, dx : int, dy : int) -> void:
	var buttons : Array[Button] = _zone_buttons(card_zone)
	if buttons.is_empty():
		return
	var columns : int = _zone_columns(card_zone)
	var index : int = _get_index(card_zone)
	var column : int = index % columns
	var target : int = _move_in_cards(buttons.size(), columns, index, dx, dy)
	match target:
		EXIT_UP:
			# Maneuvers on top, charms below
			if card_zone == Zone.CHARMS and !maneuver_buttons.is_empty():
				_cross_to(Zone.MANEUVERS, column, true)
			else:
				_set_zone(Zone.REPAIR)
		EXIT_DOWN:
			if card_zone == Zone.MANEUVERS and !charm_buttons.is_empty():
				_cross_to(Zone.CHARMS, column, false)
			else:
				_set_zone(Zone.BACK)
		EXIT_LEFT, EXIT_RIGHT:
			pass  # row ends: nothing on the sides (the description panel is not selectable)
		_:
			_set_index(card_zone, target)
			_set_zone(card_zone)


## Moves inside a card grid: the new index, or an EXIT_* value when the move leaves it
func _move_in_cards(count : int, columns : int, index : int, dx : int, dy : int) -> int:
	var column : int = index % columns
	var row : int = floori(float(index) / columns)
	if dy < 0:
		return EXIT_UP if row == 0 else index - columns
	if dy > 0:
		return EXIT_DOWN if index + columns > count - 1 else index + columns
	if dx < 0:
		return EXIT_LEFT if column == 0 else index - 1
	if dx > 0:
		return EXIT_RIGHT if column == columns - 1 or index == count - 1 else index + 1
	return index


## Vertical move between the two card grids: same column, nearest row of the other grid
func _cross_to(target_zone : Zone, column : int, to_last_row : bool) -> void:
	var buttons : Array[Button] = _zone_buttons(target_zone)
	if buttons.is_empty():
		return
	var columns : int = _zone_columns(target_zone)
	var row : int = floori(float(buttons.size() - 1) / columns) if to_last_row else 0
	_set_index(target_zone, mini(row * columns + mini(column, columns - 1), buttons.size() - 1))
	_set_zone(target_zone)


## Repair (top right): the top right maneuver card, the charms when there is no maneuver
func _enter_from_repair() -> void:
	if !maneuver_buttons.is_empty():
		_cross_to(Zone.MANEUVERS, _zone_columns(Zone.MANEUVERS) - 1, false)
	elif !charm_buttons.is_empty():
		_cross_to(Zone.CHARMS, _zone_columns(Zone.CHARMS) - 1, false)


## Continue (bottom center): the middle card of the charms' last row, the maneuvers when there is no charm
func _enter_from_back() -> void:
	if !charm_buttons.is_empty():
		_cross_to(Zone.CHARMS, floori(_zone_columns(Zone.CHARMS) * 0.5), true)
	elif !maneuver_buttons.is_empty():
		_cross_to(Zone.MANEUVERS, floori(_zone_columns(Zone.MANEUVERS) * 0.5), true)


func _zone_buttons(card_zone : Zone) -> Array[Button]:
	return charm_buttons if card_zone == Zone.CHARMS else maneuver_buttons


func _zone_columns(card_zone : Zone) -> int:
	var container : GridContainer = charm_container if card_zone == Zone.CHARMS else maneuver_container
	return maxi(container.columns, 1)


func _get_index(card_zone : Zone) -> int:
	return charm_index if card_zone == Zone.CHARMS else maneuver_index


func _set_index(card_zone : Zone, index : int) -> void:
	if card_zone == Zone.CHARMS:
		charm_index = index
	else:
		maneuver_index = index


func _set_zone(new_zone : Zone) -> void:
	zone = new_zone
	match zone:
		Zone.CHARMS:
			charm_buttons[charm_index].grab_focus()
		Zone.MANEUVERS:
			maneuver_buttons[maneuver_index].grab_focus()
		Zone.REPAIR:
			repair_button.grab_focus()
		Zone.REROLL:
			reroll_button.grab_focus()
		Zone.BACK:
			back.grab_focus()
	_refresh_details()


func _on_button_focus_entered(button_zone : Zone) -> void:
	zone = button_zone
	_refresh_details()


## Focus or mouse over a card: its description
func _on_card_focus_entered(card_zone : Zone, index : int) -> void:
	zone = card_zone
	_set_index(card_zone, index)
	_refresh_details()


# ---------------- MANEUVER CARDS ----------------

func _refresh_maneuvers() -> void:
	for i : int in maneuver_cards.size():
		var data : ManeuverData = ShopManager.current_maneuvers[i]
		var price : int = _get_price(data)
		maneuver_cards[i].refresh(
			_get_level_text(data),
			price,
			int(price * ShopManager.discount.get_value()),
			_get_final_price(data) <= InventoryManager.blood_tank_q,
			ShopManager.current_maneuvers_sold.has(data))


## NEW = not unlocked yet, "Lvl n -> n+1" = the upgrade offered, current level (or MAX) once sold
func _get_level_text(data : ManeuverData) -> String:
	if !LoadoutManager.owns(data.maneuver_type):
		return tr("SHOP_MANEUVER_NEW")
	var level : int = LoadoutManager.get_maneuver_level(data.maneuver_type)
	if ShopManager.current_maneuvers_sold.has(data):
		if level >= LoadoutManager.MAX_MANEUVER_LEVEL:
			return tr("SHOP_LEVEL_MAX")
		return tr("SHOP_LEVEL_CURRENT") % level
	return tr("SHOP_LEVEL_NEXT") % [level, level + 1]


## Description panel: the selected charm or maneuver card (name, icon, description). Empty on the buttons
func _refresh_details() -> void:
	if zone == Zone.CHARMS and charm_index < ShopManager.current_charms.size():
		var charm : CharmData = ShopManager.current_charms[charm_index]
		_show_desc(InventoryManager.get_charm_name(charm), charm.icon, tr(charm.description))
		return
	if zone != Zone.MANEUVERS or maneuver_index >= ShopManager.current_maneuvers.size():
		_show_desc("", null, "")
		return
	var data : ManeuverData = ShopManager.current_maneuvers[maneuver_index]
	var owned : bool = LoadoutManager.owns(data.maneuver_type)
	var level : int = LoadoutManager.get_maneuver_level(data.maneuver_type)
	var lines : PackedStringArray = []
	lines.append(tr(data.description_key))
	lines.append("")
	if ShopManager.current_maneuvers_sold.has(data):
		lines.append(tr("SHOP_SOLD"))
	elif !owned:
		lines.append(_get_buy_status(data, "SHOP_UNLOCK"))
	else:
		# What the next level brings
		var next_level : int = level + 1
		lines.append("%s %d → %d" % [tr("PART_LEVEL"), level, next_level])
		lines.append(tr("MANEUVER_LEVEL_EFFECT") % String.num(LoadoutManager.LEVEL_SHARE_FACTORS[next_level], 2))
		var combo_max_bonus : PackedFloat32Array = LoadoutManager.car.maneuver_level_combo_max
		if level < combo_max_bonus.size():
			lines.append(tr("SHOP_COMBO_MAX_BONUS") % String.num(combo_max_bonus[level], 2))
		lines.append("")
		lines.append(_get_buy_status(data, "SHOP_LEVEL_BUY"))
	_show_desc(tr(data.name_key), data.icon, "\n".join(lines))


func _show_desc(title : String, icon_texture : Texture2D, text : String) -> void:
	desc_name_label.text = title
	desc_icon.texture = icon_texture
	# No icon (buttons): hide its background too
	(desc_icon.get_parent() as CanvasItem).visible = icon_texture != null
	maneuver_desc_label.text = text


func _get_buy_status(data : ManeuverData, buy_key : String) -> String:
	if _get_final_price(data) > InventoryManager.blood_tank_q:
		return tr("SHOP_NOT_ENOUGH_BLOOD")
	return tr(buy_key)


## Price of the card (unlock or next level): rolled once, kept until the next raid or a reroll
func _get_price(data : ManeuverData) -> int:
	if ShopManager.current_maneuver_prices.has(data):
		return ShopManager.current_maneuver_prices[data]
	# Purchase index: 0 = unlock, then the level bought (1..5)
	var purchase : int = 0
	if LoadoutManager.owns(data.maneuver_type):
		purchase = LoadoutManager.get_maneuver_level(data.maneuver_type) + 1
	var base : float = data.base_price * GameMaster.difficulty_mod * (1.0 + upgrade_price_step * purchase)
	var price : int = roundi(randf_range(base * (1.0 - price_variation), base * (1.0 + price_variation)))
	ShopManager.current_maneuver_prices[data] = price
	return price


func _get_final_price(data : ManeuverData) -> int:
	var price : int = _get_price(data)
	return mini(price, int(price * ShopManager.discount.get_value()))


## New maneuver: unlock. Owned one: next level. The card is sold until the next raid or a reroll
func _try_buy_maneuver(index : int) -> void:
	if index < 0 or index >= ShopManager.current_maneuvers.size():
		return
	var data : ManeuverData = ShopManager.current_maneuvers[index]
	if ShopManager.current_maneuvers_sold.has(data):
		return
	var owned : bool = LoadoutManager.owns(data.maneuver_type)
	if owned and !LoadoutManager.can_upgrade(data.maneuver_type):
		return
	var final_price : int = _get_final_price(data)
	if final_price > InventoryManager.blood_tank_q:
		maneuver_cards[index].not_enough_cash()
		return
	InventoryManager.blood_tank_q -= final_price
	BloodBars.update_blood_tank()
	if owned:
		LoadoutManager.upgrade(data.maneuver_type)
	else:
		LoadoutManager.unlock(data.maneuver_type)
	ShopManager.current_maneuvers_sold.append(data)
	SignalManager.emit_signal("update_fortune")


# ---------------- OFFER / BUTTONS ----------------

func pick_boost(proposed_boosts : Array[BoostData], pick_list : Array[BoostData]) -> BoostData:
	var attempts : int = 0
	while attempts <1000:
		attempts += 1
		var boost : BoostData = ShopManager.pick_boost(pick_list)

		if proposed_boosts.has(boost):
			continue
		if boost.target_weapon != null and !WeaponsManager.weapons.has(boost.target_weapon):
			continue
		if boost.target_weapon != null and proposed_boosts.any(
				func(check : BoostData) -> bool: return InventoryManager.get_boost_name(check) == InventoryManager.get_boost_name(boost)):
			continue

		return boost
	# No valid boost left (e.g. an equipped weapon has no matching boost): caller shows fewer cards
	push_warning("shop : no valid boost found after 1000 attempts")
	return null


func _on_item_baught() -> void:
	if self.visible:
		cash_register.play()
		update_reroll_button()
		# Prices turn red when the blood bank no longer covers them, a bought card shows as sold
		_refresh_maneuvers()
		_refresh_details()

func _on_back_pressed() -> void:
	SceneManager.load_level(SceneManager.SCENES.ROADMAP)


func _on_visibility_changed() -> void:
	if self.visible and items_ready :
		_set_zone(Zone.REPAIR)
		SignalManager.charm_triggered.emit(ShopManager.CONST_REFS.Charm_Discount)

## New offer (first visit after a raid, or the paid reroll button): charms and maneuvers together,
## prices and sold cards reset with them. Stored until the next raid
func reroll() -> void :
	ShopManager.current_charm_prices.clear()
	ShopManager.current_charms = ShopManager.pick_charms(nb_charm)
	ShopManager.current_maneuver_prices.clear()
	ShopManager.current_maneuvers_sold.clear()
	ShopManager.current_maneuvers = ShopManager.pick_maneuvers(nb_maneuver)
	ShopManager.offer_ready = true
	_build_offer()


## Cards of the stored offer. The cards placed in the scene are layout previews: replaced here
func _build_offer() -> void:
	_clear_container(charm_container)
	_clear_container(maneuver_container)
	charm_buttons.clear()
	maneuver_cards.clear()
	maneuver_buttons.clear()
	# One bought during an earlier visit shows as sold (see the charm card setup)
	for charm : CharmData in ShopManager.current_charms:
		var charm_card : Control = charm_scene.instantiate()
		charm_container.add_child(charm_card)
		charm_card.setup(charm, true)
		var card_button : Button = charm_card.get_node_or_null("Confirm") as Button
		if card_button != null:
			card_button.focus_entered.connect(_on_card_focus_entered.bind(Zone.CHARMS, charm_buttons.size()))
			card_button.mouse_entered.connect(_on_card_focus_entered.bind(Zone.CHARMS, charm_buttons.size()))
			charm_buttons.append(card_button)
	for data : ManeuverData in ShopManager.current_maneuvers:
		var maneuver_card : ShopManeuverCard = maneuver_card_scene.instantiate() as ShopManeuverCard
		maneuver_container.add_child(maneuver_card)
		maneuver_card.setup(data)
		var index : int = maneuver_buttons.size()
		maneuver_card.confirm.pressed.connect(_try_buy_maneuver.bind(index))
		maneuver_card.confirm.focus_entered.connect(_on_card_focus_entered.bind(Zone.MANEUVERS, index))
		maneuver_card.confirm.mouse_entered.connect(_on_card_focus_entered.bind(Zone.MANEUVERS, index))
		maneuver_cards.append(maneuver_card)
		maneuver_buttons.append(maneuver_card.confirm)
	charm_index = clampi(charm_index, 0, maxi(charm_buttons.size() - 1, 0))
	maneuver_index = clampi(maneuver_index, 0, maxi(maneuver_buttons.size() - 1, 0))
	_refresh_maneuvers()
	items_ready = true


func _clear_container(container : Node) -> void:
	for child : Node in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _on_reroll_pressed() -> void:
	var cost : int = ShopManager.get_reroll_cost()
	if cost > InventoryManager.blood_tank_q:
		return
	reroll()

	InventoryManager.blood_tank_q -= cost
	BloodBars.update_blood_tank()
	SignalManager.emit_signal("update_fortune")

	ShopManager.use_reroll()
	reroll_cost_label.text = str(ShopManager.get_reroll_cost())
	reroll_button.grab_focus()

func update_reroll_button()-> void :
	if ShopManager.get_reroll_cost() <= InventoryManager.blood_tank_q:
		reroll_label.add_theme_color_override("font_color",Color.BLACK)
		reroll_cost_label.add_theme_color_override("font_color",Color.BLACK)
	else :
		reroll_label.add_theme_color_override("font_color",Color.RED)
		reroll_cost_label.add_theme_color_override("font_color",Color.RED)

## Charm bought with every slot full: it waits in the inventory, the player is told where it went
func _on_charm_stored(charm : CharmData) -> void:
	if inventory_popup == null:
		return
	inventory_popup_label.text = tr("SHOP_CHARM_STORED") % InventoryManager.get_charm_name(charm)
	inventory_popup.show()
	popup_time_left = inventory_popup_duration
