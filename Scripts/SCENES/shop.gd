extends Control
## Shop: maneuver levels on the left (one row per maneuver: icon = unlock, then one cell per level, like the car level-up),
## 4 random charms on the right. Navigation by code over zones: grid, charms, repair / reroll / back buttons

enum Zone { GRID, CHARMS, REPAIR, REROLL, BACK }
const LEVEL_COUNT : int = 5
const COLUMN_COUNT : int = LEVEL_COUNT + 1  # column 0 = the maneuver icon (unlock), 1..5 = its levels

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
@export var maneuver_rows : Control                           # LevelUp: one row per maneuver
@export var row_maneuvers : Array[ManeuverManager.Type] = []  # maneuver of each row, same order as the rows
@export var maneuver_desc_label : Label                       # ManeuverDesc
@export var desc_name_label : Label     # DescPanel/Name
@export var desc_icon : TextureRect     # DescPanel/IconBkg/Icon
@export var price_variation : float = 0.25    # random +/- share around the base price
@export var upgrade_price_step : float = 0.5  # price x(1 + step x purchase): unlock 1x, lv1 1.5x ... lv5 3.5x
@export_group("Cells")
@export var obtained_color : Color = Color("740000")
@export var locked_color : Color = Color(0.18, 0.18, 0.18)
@export var locked_icon_color : Color = Color(0.25, 0.25, 0.25)  # icon background of a maneuver not unlocked yet
@export var icon_focus_color : Color = Color.WHITE                # icon background when selected
@export var focus_border_color : Color = Color.WHITE
@export var focus_border_width : int = 2

#var nb_boost : int
var nb_ammo : int = 2
var nb_weapon : int = 2
var nb_charm : int = 4

var font_button : Array = FontManager.FONTS[FontManager.types.BUTTON]
var font_button_focus : Array = FontManager.FONTS[FontManager.types.BUTTON_FOCUS]
var font_button_pressed : Array = FontManager.FONTS[FontManager.types.BUTTON_PRESSED]
var font_button_hover : Array = FontManager.FONTS[FontManager.types.BUTTON_HOVER]

var items_ready : bool = false

# ---- Maneuver grid ----
var row_data : Array[ManeuverData] = []     # one per row
var row_icon_rects : Array[ColorRect] = []
var row_icon_colors : PackedColorArray = PackedColorArray()  # icon background set in the editor (unlocked look)
var row_cells : Array[Array] = []           # [row][level - 1] = Label
var row_bars : Array[Array] = []            # [row][level - 1] = ProgressBar before that level
var row_price_boxes : Array[Control] = []
var row_price_tags : Array[Label] = []
var row_discount_tags : Array[Label] = []
var row_strike_prices : Array[Control] = []

# ---- Navigation ----
var charm_buttons : Array[Button] = []      # Confirm button of each charm card
var zone : Zone = Zone.REPAIR
var return_zone : Zone = Zone.GRID          # where down from Repair / up from Back goes back to
var focus_row : int = 0
var focus_column : int = 1
var charm_index : int = 0

# ---- Cell looks, built once from the first cell ----
var style_obtained : StyleBoxFlat
var style_locked : StyleBoxFlat
var style_obtained_focus : StyleBoxFlat
var style_locked_focus : StyleBoxFlat


func _ready() -> void:
	player = SurvivorsManager.on_board_survivors[0]

	SignalManager.update_fortune.connect(_on_item_baught)
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

	_build_grid()
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
	_refresh_grid()

	SignalManager.emit_signal("shop_entered")
	BloodBars.show()


# ---------------- INPUT ----------------

## Navigation polled: one press per push of the stick (no repeat from analog motion events)
func _process(_delta : float) -> void:
	if Input.is_action_just_pressed("ui_up"):
		_move_focus(0, -1)
	elif Input.is_action_just_pressed("ui_down"):
		_move_focus(0, 1)
	elif Input.is_action_just_pressed("ui_left"):
		_move_focus(-1, 0)
	elif Input.is_action_just_pressed("ui_right"):
		_move_focus(1, 0)


func _input(event: InputEvent) -> void:
	# Mouse: handled by the cells, cards and buttons themselves
	if event is InputEventMouse:
		return
	# Directions are handled in _process: Godot's own focus moves would fight it
	if event.is_action("ui_up") or event.is_action("ui_down") or event.is_action("ui_left") or event.is_action("ui_right"):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("confirm"):
		back.grab_focus()
	elif zone == Zone.GRID and event.is_action_pressed("ui_accept"):
		_try_buy(focus_row, focus_column)
		get_viewport().set_input_as_handled()
	# Charms and buttons: ui_accept presses the focused button (Godot)


func _move_focus(dx : int, dy : int) -> void:
	var last_row : int = row_data.size() - 1
	var last_charm : int = charm_buttons.size() - 1
	var charm_columns : int = maxi(charm_container.columns, 1)
	var charm_rows : int = ceili(float(charm_buttons.size()) / charm_columns)
	match zone:
		Zone.GRID:
			if row_data.is_empty():
				return
			if dy < 0 and focus_row == 0:
				return_zone = Zone.GRID
				_set_zone(Zone.REPAIR)
			elif dy > 0 and focus_row == last_row:
				return_zone = Zone.GRID
				_set_zone(Zone.BACK)
			elif dx < 0 and focus_column == 0 and !charm_buttons.is_empty():
				# Left of the icons: the right column of the charms, at the same height
				var target_charm_row : int = clampi(int(float(focus_row) * charm_rows / row_data.size()), 0, charm_rows - 1)
				charm_index = mini(target_charm_row * charm_columns + charm_columns - 1, last_charm)
				_set_zone(Zone.CHARMS)
			else:
				focus_row = clampi(focus_row + dy, 0, last_row)
				focus_column = clampi(focus_column + dx, 0, COLUMN_COUNT - 1)
				_refresh_grid()
		Zone.CHARMS:
			var charm_column : int = charm_index % charm_columns
			var charm_row : int = floori(float(charm_index) / charm_columns)
			if dy < 0 and charm_row == 0:
				return_zone = Zone.CHARMS
				_set_zone(Zone.REPAIR)
			elif dy > 0 and charm_index + charm_columns > last_charm:
				return_zone = Zone.CHARMS
				_set_zone(Zone.BACK)
			elif dx > 0 and (charm_column == charm_columns - 1 or charm_index == last_charm):
				# Right of the charms: the icon of the maneuver row at the same height
				if row_data.is_empty():
					return
				focus_row = clampi(int(float(charm_row) * row_data.size() / charm_rows), 0, last_row)
				focus_column = 0
				_set_zone(Zone.GRID)
			elif dx != 0:
				charm_index = clampi(charm_index + dx, 0, last_charm)
				_set_zone(Zone.CHARMS)
			elif dy != 0:
				charm_index = clampi(charm_index + dy * charm_columns, 0, last_charm)
				_set_zone(Zone.CHARMS)
		Zone.REPAIR:
			if dy < 0:
				_set_zone(Zone.REROLL)
			elif dy > 0:
				# Back to the top of the zone we came from
				if return_zone == Zone.CHARMS and !charm_buttons.is_empty():
					charm_index = 0
					_set_zone(Zone.CHARMS)
				elif !row_data.is_empty():
					focus_row = 0
					_set_zone(Zone.GRID)
		Zone.REROLL:
			if dy > 0:
				_set_zone(Zone.REPAIR)
		Zone.BACK:
			if dy < 0:
				# Back to the bottom of the zone we came from
				if return_zone == Zone.CHARMS and !charm_buttons.is_empty():
					charm_index = last_charm
					_set_zone(Zone.CHARMS)
				elif !row_data.is_empty():
					focus_row = last_row
					_set_zone(Zone.GRID)


func _set_zone(new_zone : Zone) -> void:
	zone = new_zone
	match zone:
		Zone.GRID:
			# The grid cells are labels: no Godot focus, the border shows the selection
			var focus_owner : Control = get_viewport().gui_get_focus_owner()
			if focus_owner != null:
				focus_owner.release_focus()
		Zone.CHARMS:
			charm_buttons[charm_index].grab_focus()
		Zone.REPAIR:
			repair_button.grab_focus()
		Zone.REROLL:
			reroll_button.grab_focus()
		Zone.BACK:
			back.grab_focus()
	_refresh_grid()


func _on_button_focus_entered(button_zone : Zone) -> void:
	zone = button_zone
	_refresh_grid()


func _on_charm_focus_entered(index : int) -> void:
	zone = Zone.CHARMS
	charm_index = index
	_refresh_grid()


func _select_cell(row : int, column : int) -> void:
	focus_row = row
	focus_column = column
	_set_zone(Zone.GRID)


func _on_cell_gui_input(event : InputEvent, row : int, column : int) -> void:
	var mouse_button : InputEventMouseButton = event as InputEventMouseButton
	if mouse_button == null or !mouse_button.pressed or mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	_select_cell(row, column)
	_try_buy(row, column)


# ---------------- MANEUVER GRID ----------------

func _build_grid() -> void:
	var rows : Array[Node] = maneuver_rows.get_children()
	for row_index : int in rows.size():
		if row_index >= row_maneuvers.size():
			push_warning("[Shop] Row Maneuvers has fewer entries than the rows")
			break
		var data : ManeuverData = LoadoutManager.get_maneuver_data(row_maneuvers[row_index])
		var row_node : Node = rows[row_index]
		if data == null:
			push_warning("[Shop] no maneuver data for the row " + row_node.name)
			continue
		var grid_row : int = row_data.size()
		row_data.append(data)

		# Icon = column 0: unlocks the maneuver
		var icon_rect : ColorRect = row_node.get_node("ColorRect") as ColorRect
		(row_node.get_node("ColorRect/TextureRect") as TextureRect).texture = data.icon
		(row_node.get_node("ColorRect/Label") as Label).text = tr(data.name_key)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		icon_rect.gui_input.connect(_on_cell_gui_input.bind(grid_row, 0))
		icon_rect.mouse_entered.connect(_select_cell.bind(grid_row, 0))
		row_icon_rects.append(icon_rect)
		row_icon_colors.append(icon_rect.color)

		var cells : Array[Label] = []
		var bars : Array[ProgressBar] = []
		for level : int in range(1, LEVEL_COUNT + 1):
			var cell : Label = row_node.get_node("Lvl%d" % level) as Label
			var bar_name : String = "ProgressBar" if level == 1 else "ProgressBar%d" % level
			var bar : ProgressBar = row_node.get_node(bar_name) as ProgressBar
			cell.mouse_filter = Control.MOUSE_FILTER_STOP
			cell.gui_input.connect(_on_cell_gui_input.bind(grid_row, level))
			cell.mouse_entered.connect(_select_cell.bind(grid_row, level))
			bar.min_value = 0.0
			bar.max_value = 100.0
			cells.append(cell)
			bars.append(bar)
		row_cells.append(cells)
		row_bars.append(bars)

		# Price of the next purchase (unlock or next level)
		var price_box : Control = row_node.get_node("Price") as Control
		row_price_boxes.append(price_box)
		row_price_tags.append(price_box.find_child("PriceTag", true, false) as Label)
		row_discount_tags.append(price_box.find_child("DiscountTag", true, false) as Label)
		row_strike_prices.append(price_box.find_child("StrikePrice", true, false) as Control)
	if !row_cells.is_empty():
		_build_styles(row_cells[0][0] as Label)


## Four shared looks (obtained / locked, with or without the focus border), from the first cell style
func _build_styles(sample : Label) -> void:
	var base : StyleBoxFlat = sample.get_theme_stylebox("normal") as StyleBoxFlat
	if base == null:
		base = StyleBoxFlat.new()
	style_obtained = base.duplicate() as StyleBoxFlat
	style_obtained.bg_color = obtained_color
	style_locked = base.duplicate() as StyleBoxFlat
	style_locked.bg_color = locked_color
	style_obtained_focus = style_obtained.duplicate() as StyleBoxFlat
	style_obtained_focus.border_color = focus_border_color
	style_obtained_focus.set_border_width_all(focus_border_width)
	style_locked_focus = style_locked.duplicate() as StyleBoxFlat
	style_locked_focus.border_color = focus_border_color
	style_locked_focus.set_border_width_all(focus_border_width)


func _refresh_grid() -> void:
	for row : int in row_data.size():
		var data : ManeuverData = row_data[row]
		var owned : bool = LoadoutManager.owns(data.maneuver_type)
		var level : int = LoadoutManager.get_maneuver_level(data.maneuver_type)
		# Icon: grey while locked, highlighted when selected
		var icon_focused : bool = zone == Zone.GRID and row == focus_row and focus_column == 0
		if icon_focused:
			row_icon_rects[row].color = icon_focus_color
		else:
			row_icon_rects[row].color = row_icon_colors[row] if owned else locked_icon_color
		for i : int in LEVEL_COUNT:
			var obtained : bool = owned and i < level
			var focused : bool = zone == Zone.GRID and row == focus_row and i + 1 == focus_column
			var style : StyleBoxFlat
			if obtained:
				style = style_obtained_focus if focused else style_obtained
			else:
				style = style_locked_focus if focused else style_locked
			(row_cells[row][i] as Label).add_theme_stylebox_override("normal", style)
			(row_bars[row][i] as ProgressBar).value = 100.0 if obtained else 0.0
		_refresh_price(row, data, owned, level)
	_refresh_details()


## Price of the next purchase, hidden once the maneuver is at its max level. Red when the blood bank is too low
func _refresh_price(row : int, data : ManeuverData, owned : bool, level : int) -> void:
	var has_next : bool = !owned or level < LoadoutManager.MAX_MANEUVER_LEVEL
	row_price_boxes[row].visible = has_next
	if !has_next:
		return
	var price : int = _get_price(data)
	var price_tag : Label = row_price_tags[row]
	var discount_tag : Label = row_discount_tags[row]
	price_tag.text = str(price)
	discount_tag.text = str(int(price * ShopManager.discount.get_value()))
	discount_tag.visible = ShopManager.apply_discount
	row_strike_prices[row].visible = ShopManager.apply_discount
	var too_expensive : bool = _get_final_price(data) > InventoryManager.blood_tank_q
	for tag : Label in [price_tag, discount_tag]:
		if too_expensive:
			tag.add_theme_color_override("font_color", Color.RED)
		else:
			tag.remove_theme_color_override("font_color")


## Description panel: the selected maneuver cell or charm (name, icon, description). Empty on the buttons
func _refresh_details() -> void:
	if zone == Zone.CHARMS and charm_index < ShopManager.current_charms.size():
		var charm : CharmData = ShopManager.current_charms[charm_index]
		_show_desc(InventoryManager.get_charm_name(charm), charm.icon, tr(charm.description))
		return
	if zone != Zone.GRID or row_data.is_empty():
		_show_desc("", null, "")
		return
	var data : ManeuverData = row_data[focus_row]
	var owned : bool = LoadoutManager.owns(data.maneuver_type)
	var level : int = LoadoutManager.get_maneuver_level(data.maneuver_type)
	var lines : PackedStringArray = []
	lines.append(tr(data.description_key))
	lines.append("")
	if focus_column == 0:
		lines.append(tr("SHOP_MANEUVER_UNLOCKED") if owned else _get_buy_status(data, "SHOP_UNLOCK"))
	else:
		lines.append("%s %d" % [tr("PART_LEVEL"), focus_column])
		lines.append(tr("MANEUVER_LEVEL_EFFECT") % String.num(LoadoutManager.LEVEL_SHARE_FACTORS[focus_column], 2))
		lines.append("")
		if !owned:
			lines.append(tr("SHOP_MANEUVER_LOCKED"))
		elif focus_column <= level:
			lines.append(tr("SHOP_LEVEL_OWNED"))
		elif focus_column == level + 1:
			lines.append(_get_buy_status(data, "SHOP_LEVEL_BUY"))
		else:
			lines.append(tr("SHOP_LEVEL_LOCKED"))
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


## Price of the next purchase (unlock, then each level): rolled once, kept until the next raid
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


## Icon of a locked maneuver: unlock (level 0). Level cell: only the next level of an unlocked maneuver
func _try_buy(row : int, column : int) -> void:
	if row < 0 or row >= row_data.size():
		return
	var data : ManeuverData = row_data[row]
	var owned : bool = LoadoutManager.owns(data.maneuver_type)
	var level : int = LoadoutManager.get_maneuver_level(data.maneuver_type)
	var is_unlock : bool = !owned and column == 0
	var is_upgrade : bool = owned and column == level + 1 and level < LoadoutManager.MAX_MANEUVER_LEVEL
	if !is_unlock and !is_upgrade:
		return
	var final_price : int = _get_final_price(data)
	if final_price > InventoryManager.blood_tank_q:
		return
	InventoryManager.blood_tank_q -= final_price
	BloodBars.update_blood_tank()
	if is_unlock:
		LoadoutManager.unlock(data.maneuver_type)
	else:
		LoadoutManager.upgrade(data.maneuver_type)
	# The next purchase gets its own price
	ShopManager.current_maneuver_prices.erase(data)
	SignalManager.emit_signal("update_fortune")
	_refresh_grid()


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
		# Prices turn red when the blood bank no longer covers them
		_refresh_grid()

func _on_back_pressed() -> void:
	SceneManager.load_level(SceneManager.SCENES.ROADMAP)


func _on_visibility_changed() -> void:
	if self.visible and items_ready : 
		_set_zone(Zone.REPAIR)
		SignalManager.charm_triggered.emit(ShopManager.CONST_REFS.Charm_Discount)

## New charm offer (first visit after a raid, or the paid reroll button): stored until the next raid.
## Maneuvers are not rolled: every one is in the grid
func reroll() -> void : 
	ShopManager.current_charm_prices.clear()
	ShopManager.current_charms = ShopManager.pick_charms(nb_charm)
	ShopManager.offer_ready = true
	_build_offer()


## Charm cards of the stored offer. The cards placed in the scene are layout previews: replaced here
func _build_offer() -> void:
	for child : Node in charm_container.get_children():
		charm_container.remove_child(child)
		child.queue_free()
	charm_buttons.clear()
	# One bought during an earlier visit shows as sold (see the charm card setup)
	for charm : CharmData in ShopManager.current_charms:
		var charm_card : Control = charm_scene.instantiate()
		charm_container.add_child(charm_card)
		charm_card.setup(charm, true)
		var card_button : Button = charm_card.get_node_or_null("Confirm") as Button
		if card_button != null:
			card_button.focus_entered.connect(_on_charm_focus_entered.bind(charm_buttons.size()))
			# Mouse over a card: its description, like the maneuver cells
			card_button.mouse_entered.connect(_on_charm_focus_entered.bind(charm_buttons.size()))
			charm_buttons.append(card_button)
	charm_index = clampi(charm_index, 0, maxi(charm_buttons.size() - 1, 0))
	items_ready = true

func _on_reroll_pressed() -> void:
	if ShopManager.get_reroll_cost() > InventoryManager.blood_tank_q:
		return
	reroll()
	
	InventoryManager.blood_tank_q -= ShopManager.get_reroll_cost()
	BloodBars.update_blood_tank()
	SignalManager.emit_signal("update_fortune")
	
	ShopManager.reroll_count += 1
	reroll_cost_label.text = str(ShopManager.get_reroll_cost())
	reroll_button.grab_focus()
	
func update_reroll_button()-> void : 
	if ShopManager.get_reroll_cost() <= InventoryManager.blood_tank_q:
		reroll_label.add_theme_color_override("font_color",Color.BLACK)
		reroll_cost_label.add_theme_color_override("font_color",Color.BLACK)
	else :
		reroll_label.add_theme_color_override("font_color",Color.RED)
		reroll_cost_label.add_theme_color_override("font_color",Color.RED)
