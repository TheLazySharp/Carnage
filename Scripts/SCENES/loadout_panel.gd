extends Control
class_name LoadoutPanel


signal closed  # the menu around takes the focus back

enum CharmZone { SLOTS, OWNED, MASTERY }

const SELECTED_COLOR: Color = Color(1.0, 0.85, 0.2)
const LOCKED_COLOR: Color = Color(0.5, 0.5, 0.5)
const MASTERY_LOCKED_COLOR: Color = Color(0.25, 0.25, 0.25)  # mastery charm not granted yet
const MANEUVERS_TAB: int = 0
const CHARMS_TAB: int = 1
const FOCUS_SCALE: float = 1.15  # focused charm cell

@export var tab_container: TabContainer
@export_group("Maneuvers tab")
@export var row_template: HBoxContainer           # RepartitionContainer: hidden, duplicated per maneuver
@export var weapon_desc_label: Label              # WeaponDesc: description of the selected row weapon
@export var weapon_count_template: VBoxContainer  # WeaponCount: hidden, duplicated per weapon on board
@export var hint_label: Label   # optional: Tips
@export var hint_label2: Label  # optional: Tips2
@export_group("Charms tab")
@export var charm_slot_template: Control          # CharmHolderContainer/Panel (icon TextureRect inside): hidden, duplicated per charm slot
@export var owned_charm_template: TextureRect     # first cell of OwnedCharmContainer: hidden, duplicated per unequipped charm
@export var slots_label: Label
@export var mastery_slots_label: Label
@export var charm_description_label: Label        # CharmDescription: focused charm
@export var mastery_slot_template: Control        # MasteryCharmHolder/Panel (icon TextureRect inside): hidden, duplicated per car part


@export var mastery_slot_parts: Array[CarData.Car_Upgrades] = [
	CarData.Car_Upgrades.ENGINE,
	CarData.Car_Upgrades.TANK,
	CarData.Car_Upgrades.BUMPER,
	CarData.Car_Upgrades.REAR_BUMPER,
	CarData.Car_Upgrades.WHEELS,
]

var read_only: bool = false  # consultation only: nothing can be changed
var previous_focus: Control = null  # focused control of the menu behind, given back on close

# ---- Maneuvers tab ----
var rows: Array[ManeuverManager.Type] = []         # owned maneuvers (navigable rows)
var row_nodes: Array[HBoxContainer] = []           # one per owned maneuver, same order as rows
var locked_row_nodes: Array[HBoxContainer] = []
var weapon_count_nodes: Array[VBoxContainer] = []  # one per weapon, same order as weapons
var weapons: Array[WeaponData] = []                # weapons of the survivors on board
var selected_row: int = 0

# ---- Charms tab ----
var slot_cells: Array[Control] = []
var slot_charms: Array[CharmData] = []
var owned_cells: Array[Control] = []
var owned_charms: Array[CharmData] = []  # bought but not equipped
var focus_zone: CharmZone = CharmZone.SLOTS
var focus_index: int = 0
var picked_zone: CharmZone = CharmZone.SLOTS
var picked_index: int = -1               # -1 = nothing picked
var mastery_cells: Array[Control] = []
var mastery_charms: Array[CharmData] = []     # charm of each cell part (granted or not, null = none set)
var mastery_boosts: Array[BoostData] = []     # car part of each cell

func _ready() -> void:
	row_template.hide()
	weapon_count_template.hide()
	charm_slot_template.hide()
	owned_charm_template.hide()
	mastery_slot_template.hide()
	var mastery_parent: Node = mastery_slot_template.get_parent()
	for i: int in mastery_slot_parts.size():
		var mastery_cell: Control = mastery_slot_template.duplicate() as Control
		mastery_parent.add_child(mastery_cell)
		mastery_parent.move_child(mastery_cell, mastery_slot_template.get_index() + 1 + i)
		mastery_cell.show()
		_prepare_cell(mastery_cell)
		mastery_cell.gui_input.connect(_on_charm_cell_input.bind(CharmZone.MASTERY, i))
		mastery_cells.append(mastery_cell)
	tab_container.set_tab_title(MANEUVERS_TAB, tr("LOADOUT_TAB_MANEUVERS"))
	tab_container.set_tab_title(CHARMS_TAB, tr("LOADOUT_TAB_CHARMS"))
	tab_container.tab_changed.connect(_on_tab_changed)
	set_process(false)
	hide()


func open(p_read_only: bool = false) -> void:
	# Needs a started run: the car sets the per-weapon limit
	if LoadoutManager.car == null:
		push_warning("[LoadoutPanel] no run started, panel not opened")
		return
	read_only = p_read_only
	# Modal in both modes: read-only only forbids changes, the panel keeps the inputs
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The menu behind must not keep its focused button: remembered, given back on close
	previous_focus = get_viewport().gui_get_focus_owner()
	get_viewport().gui_release_focus()
	# Consulting must not change anything: pending weapons and new maneuvers wait for an editable opening
	if !read_only:
		# New weapons are pre-placed: validating without touching anything is never a loss
		LoadoutManager.auto_assign_pending()
		LoadoutManager.has_new_maneuver = false
		# Slots lowered since the last opening (job lost...): extra charms go back to the inventory
		CharmsManager.fit_to_slots()
	weapons.clear()
	for survivor: SurvivorData in SurvivorsManager.on_board_survivors:
		if survivor.weapon != null and !weapons.has(survivor.weapon):
			weapons.append(survivor.weapon)
	selected_row = 0
	_build_rows()
	_build_weapon_counts()
	_refresh()
	_build_charms()
	tab_container.current_tab = MANEUVERS_TAB
	_reset_charm_focus()
	if hint_label != null:
		hint_label.text = tr("LOADOUT_HINT_READ_ONLY") if read_only else tr("LOADOUT_HINT_EDIT")
	show()
	set_process(true)


func close() -> void:
	if !visible:
		return
	hide()
	set_process(false)
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()
	previous_focus = null
	closed.emit()


func _input(event: InputEvent) -> void:
	if !visible:
		return
	if event is InputEventMouse:
		return
	if event.is_action("pause"):
		return
	if event.is_action_pressed("ui_back") or event.is_action_pressed("loadout"):
		close()
	elif event.is_action_pressed("ui_accept"):
		if read_only or tab_container.current_tab == MANEUVERS_TAB:
			close()
		else:
			_accept_charm()
	get_viewport().set_input_as_handled()


## Runs only while the panel is open. Input keeps one press per push of the stick or trigger
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("go_previous"):
		_change_tab(-1)
	elif Input.is_action_just_pressed("go_next"):
		_change_tab(1)
	elif Input.is_action_just_pressed("ui_up"):
		_navigate(0, -1)
	elif Input.is_action_just_pressed("ui_down"):
		_navigate(0, 1)
	elif Input.is_action_just_pressed("ui_left"):
		_navigate(-1, 0)
	elif Input.is_action_just_pressed("ui_right"):
		_navigate(1, 0)


func _navigate(dx: int, dy: int) -> void:
	if tab_container.current_tab == MANEUVERS_TAB:
		if dy != 0:
			_move_selection(dy)
		elif !read_only:
			_cycle_weapon(dx)
	else:
		_move_charm_focus(dx, dy)

func _change_tab(direction: int) -> void:
	tab_container.current_tab = wrapi(tab_container.current_tab + direction, 0, tab_container.get_tab_count())


func _on_tab_changed(_tab: int) -> void:
	# Keyboard, gamepad or mouse: a pick never survives a tab change
	_reset_charm_focus()


## remove_child first: queue_free alone keeps the old nodes in the layout until the end of the frame
func _free_nodes(nodes: Array) -> void:
	for node: Node in nodes:
		node.get_parent().remove_child(node)
		node.queue_free()
	nodes.clear()


# ---------------- MANEUVERS TAB ----------------


func _build_rows() -> void:
	_free_nodes(row_nodes)
	_free_nodes(locked_row_nodes)
	rows.clear()
	var locked: Array[ManeuverManager.Type] = []
	for maneuver_type: ManeuverManager.Type in ManeuverManager.Type.values():
		# The loop is the car ultimate, not a weapon slot
		if maneuver_type == ManeuverManager.Type.LOOP:
			continue
		if LoadoutManager.owns(maneuver_type):
			rows.append(maneuver_type)
		else:
			locked.append(maneuver_type)
	for maneuver_type: ManeuverManager.Type in rows:
		row_nodes.append(_add_row(maneuver_type, false))
	# Locked maneuvers shown at the bottom, greyed: bought at the shop
	for maneuver_type: ManeuverManager.Type in locked:
		locked_row_nodes.append(_add_row(maneuver_type, true))


func _add_row(maneuver_type: ManeuverManager.Type, is_locked: bool) -> HBoxContainer:
	var row: HBoxContainer = row_template.duplicate() as HBoxContainer
	var rows_parent: Node = row_template.get_parent()
	rows_parent.add_child(row)
	# Right after the template and the rows already added: always above WeaponDesc
	rows_parent.move_child(row, row_template.get_index() + 1 + row_nodes.size() + locked_row_nodes.size())
	row.show()
	var data: ManeuverData = LoadoutManager.get_maneuver_data(maneuver_type)
	(row.get_node("ManeuverIcon") as TextureRect).texture = data.icon if data != null else null
	var maneuver_label : String = LoadoutManager.get_maneuver_display_name(maneuver_type)
	if !is_locked:
		maneuver_label += "  %s %d" % [tr("PART_LEVEL"), LoadoutManager.get_maneuver_level(maneuver_type)]
	(row.get_node("ManeuverName") as Label).text = maneuver_label
	if is_locked:
		(row.get_node("WeaponIcon") as TextureRect).texture = null
		(row.get_node("WeaponName") as Label).text = tr("LOADOUT_LOCKED")
		row.modulate = LOCKED_COLOR
	return row


func _build_weapon_counts() -> void:
	_free_nodes(weapon_count_nodes)
	var counts_parent: Node = weapon_count_template.get_parent()
	for weapon: WeaponData in weapons:
		var count_node: VBoxContainer = weapon_count_template.duplicate() as VBoxContainer
		counts_parent.add_child(count_node)
		count_node.show()
		(count_node.get_node("WeaponIcon") as TextureRect).texture = weapon.weapon_icon
		weapon_count_nodes.append(count_node)


func _move_selection(direction: int) -> void:
	if rows.is_empty():
		return
	selected_row = wrapi(selected_row + direction, 0, rows.size())
	_refresh()


func _cycle_weapon(direction: int) -> void:
	if rows.is_empty():
		return
	var maneuver_type: ManeuverManager.Type = rows[selected_row]
	var options: Array[WeaponData] = [null]
	options.append_array(weapons)
	var index: int = options.find(LoadoutManager.get_weapon(maneuver_type))
	for step: int in options.size():
		index = wrapi(index + direction, 0, options.size())
		var candidate: WeaponData = options[index]
		if candidate == null:
			LoadoutManager.unassign(maneuver_type)
			break
		# assign() refuses a weapon already on its maximum: skip to the next one
		if LoadoutManager.assign(maneuver_type, candidate):
			break
	_refresh()


func _refresh() -> void:
	for i: int in rows.size():
		var row: HBoxContainer = row_nodes[i]
		var weapon: WeaponData = LoadoutManager.get_weapon(rows[i])
		# No weapon: empty icon (its minimum size keeps the column aligned)
		(row.get_node("WeaponIcon") as TextureRect).texture = weapon.weapon_icon if weapon != null else null
		var weapon_name: String = "-" if weapon == null else tr(weapon.weapon_name)
		# Read-only: the selected row is highlighted (its description shows), but no arrows: nothing to cycle
		var is_selected: bool = i == selected_row
		var weapon_label: Label = row.get_node("WeaponName") as Label
		weapon_label.text = "<  %s  >" % weapon_name if is_selected and !read_only else weapon_name
		var color: Color = SELECTED_COLOR if is_selected else Color.WHITE
		(row.get_node("ManeuverName") as Label).modulate = color
		weapon_label.modulate = color
	_refresh_weapon_desc()
	_refresh_weapon_counts()


func _refresh_weapon_desc() -> void:
	if weapon_desc_label == null:
		return
	var weapon: WeaponData = null
	if !rows.is_empty():
		weapon = LoadoutManager.get_weapon(rows[selected_row])
	weapon_desc_label.text = "" if weapon == null else tr(weapon.description)


func _refresh_weapon_counts() -> void:
	for i: int in weapons.size():
		(weapon_count_nodes[i].get_node("WeaponQ") as Label).text = "%d / %d" % [
			LoadoutManager.count_assignments(weapons[i]), LoadoutManager.car.maneuvers_per_weapon]


# ---------------- CHARMS TAB ----------------

func _build_charms() -> void:
	_free_nodes(slot_cells)
	_free_nodes(owned_cells)
	if ShopManager.all_car_boosts.is_empty():
		ShopManager.load_pools()
	mastery_charms.clear()
	mastery_boosts.clear()
	# One cell per slot, in the equip order: the empty ones at the end
	for i: int in CharmsManager.get_slot_count():
		slot_charms.append(CharmsManager.holder[i] if i < CharmsManager.holder.size() else null)
	for charm: CharmData in CharmsManager.owned:
		if !CharmsManager.is_equipped(charm):
			owned_charms.append(charm)
	for i: int in slot_charms.size():
		slot_cells.append(_add_charm_cell(charm_slot_template, slot_charms[i], CharmZone.SLOTS, i))
	for i: int in owned_charms.size():
		owned_cells.append(_add_charm_cell(owned_charm_template, owned_charms[i], CharmZone.OWNED, i))
	mastery_charms.clear()
	mastery_boosts.clear()
	for i: int in mastery_cells.size():
		var part_boost: BoostData = _get_part_boost(mastery_slot_parts[i]) if i < mastery_slot_parts.size() else null
		mastery_boosts.append(part_boost)
		mastery_charms.append(part_boost.mastery_charm if part_boost != null else null)
	print("[MASTERY] cells: ", mastery_cells.size(), " | car boosts loaded: ", ShopManager.all_car_boosts.size())

func _add_charm_cell(template: Control, charm: CharmData, zone: CharmZone, index: int) -> Control:
	var cell: Control = template.duplicate() as Control
	var cells_parent: Node = template.get_parent()
	cells_parent.add_child(cell)
	# Right after the template and the cells already added, whatever else the container holds
	cells_parent.move_child(cell, template.get_index() + 1 + index)
	cell.show()
	# Empty slot: no icon, the panel keeps showing the slot
	_get_cell_icon(cell).texture = charm.icon if charm != null else null
	_prepare_cell(cell)
	cell.gui_input.connect(_on_charm_cell_input.bind(zone, index))
	return cell


func _reset_charm_focus() -> void:
	focus_zone = CharmZone.MASTERY
	focus_index = 0
	picked_index = -1
	_refresh_charms()


## Mastery = top row, slots = one row, owned charms = a grid with the OwnedCharmContainer columns
func _move_charm_focus(dx: int, dy: int) -> void:
	var columns: int = maxi((owned_charm_template.get_parent() as GridContainer).columns, 1)
	if dx != 0:
		var zone_size: int = slot_charms.size()
		if focus_zone == CharmZone.OWNED:
			zone_size = owned_charms.size()
		elif focus_zone == CharmZone.MASTERY:
			zone_size = mastery_cells.size()
		if zone_size == 0:
			return
		focus_index = wrapi(focus_index + dx, 0, zone_size)
	elif dy > 0:
		if focus_zone == CharmZone.MASTERY:
			if !slot_charms.is_empty():
				focus_zone = CharmZone.SLOTS
				focus_index = mini(focus_index, slot_charms.size() - 1)
			elif !owned_charms.is_empty():
				focus_zone = CharmZone.OWNED
				focus_index = mini(focus_index, owned_charms.size() - 1)
		elif focus_zone == CharmZone.SLOTS:
			if owned_charms.is_empty():
				return
			focus_zone = CharmZone.OWNED
			focus_index = mini(focus_index, owned_charms.size() - 1)
		elif focus_index + columns < owned_charms.size():
			focus_index += columns
	elif dy < 0:
		if focus_zone == CharmZone.OWNED:
			if focus_index >= columns:
				focus_index -= columns
			elif !slot_charms.is_empty():
				focus_zone = CharmZone.SLOTS
				focus_index = mini(focus_index, slot_charms.size() - 1)
		elif focus_zone == CharmZone.SLOTS and !mastery_cells.is_empty():
			focus_zone = CharmZone.MASTERY
			focus_index = mini(focus_index, mastery_cells.size() - 1)
	_refresh_charms()


## First accept picks the focused cell, an accept on the other zone swaps them
func _accept_charm() -> void:
	# Mastery slot: switches its charm on / off (no pick, no swap)
	if focus_zone == CharmZone.MASTERY:
		picked_index = -1
		var mastery_charm: CharmData = _get_focused_charm()
		if mastery_charm != null and CharmsManager.has_mastery(mastery_charm):
			CharmsManager.toggle_mastery(mastery_charm)
		_refresh_charms()
		return
	if picked_index < 0:
		picked_zone = focus_zone
		picked_index = focus_index
	elif picked_zone == focus_zone:
		# Same cell: cancel. Another cell of the same zone: pick it instead
		picked_index = -1 if picked_index == focus_index else focus_index
	else:
		var slot_index: int = picked_index if picked_zone == CharmZone.SLOTS else focus_index
		var owned_index: int = picked_index if picked_zone == CharmZone.OWNED else focus_index
		CharmsManager.swap(slot_charms[slot_index], owned_charms[owned_index])
		picked_index = -1
		focus_zone = CharmZone.SLOTS
		focus_index = slot_index
		# Deferred: a mouse click comes from the gui_input of a cell that the rebuild frees
		_rebuild_charms.call_deferred()
		return
	_refresh_charms()


func _rebuild_charms() -> void:
	_build_charms()
	_refresh_charms()


func _on_charm_cell_input(event: InputEvent, zone: CharmZone, index: int) -> void:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button == null or !mouse_button.pressed or mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	focus_zone = zone
	focus_index = index
	if read_only:
		_refresh_charms()
	else:
		_accept_charm()


func _get_focused_charm() -> CharmData:
	var zone_charms: Array[CharmData] = slot_charms
	if focus_zone == CharmZone.OWNED:
		zone_charms = owned_charms
	elif focus_zone == CharmZone.MASTERY:
		zone_charms = mastery_charms
	if focus_index < 0 or focus_index >= zone_charms.size():
		return null
	return zone_charms[focus_index]


func _refresh_charms() -> void:
	for i: int in slot_cells.size():
		_style_charm_cell(slot_cells[i], CharmZone.SLOTS, i)
	for i: int in owned_cells.size():
		_style_charm_cell(owned_cells[i], CharmZone.OWNED, i)
	for i: int in mastery_cells.size():
		_style_mastery_cell(i)
	if slots_label != null:
		slots_label.text = str("Charms : ", CharmsManager.holder.size(),"/",CharmsManager.get_slot_count())
		#slots_label.text = "%s : %d/%d" % [tr("LOADOUT_TAB_CHARMS"), CharmsManager.holder.size(), CharmsManager.get_slot_count()]
	if mastery_slots_label != null:
		mastery_slots_label.text = "%s : %d/%d" % [tr("LOADOUT_MASTERY_SLOTS"), CharmsManager.mastery_owned.size(), mastery_slot_parts.size()]
	if charm_description_label != null:
		var charm: CharmData = _get_focused_charm()
		if charm == null:
			charm_description_label.text = ""
		else:
			var description: String = "%s\n\n%s" % [InventoryManager.get_charm_name(charm), tr(charm.description)]
			if focus_zone == CharmZone.MASTERY:
				description += "\n\n" + _get_mastery_status(focus_index)
			charm_description_label.text = description


func _style_charm_cell(cell: Control, zone: CharmZone, index: int) -> void:
	var is_focused: bool = zone == focus_zone and index == focus_index
	var is_picked: bool = zone == picked_zone and index == picked_index
	cell.scale = Vector2.ONE * (FOCUS_SCALE if is_focused else 1.0)
	cell.modulate = SELECTED_COLOR if is_picked else Color.WHITE


func _style_mastery_cell(index: int) -> void:
	var cell: Control = mastery_cells[index]
	var icon: TextureRect = _get_cell_icon(cell)
	var charm: CharmData = mastery_charms[index] if index < mastery_charms.size() else null
	icon.texture = charm.icon if charm != null else null
	var is_focused: bool = focus_zone == CharmZone.MASTERY and index == focus_index
	cell.scale = Vector2.ONE * (FOCUS_SCALE if is_focused else 1.0)
	if charm == null or !CharmsManager.has_mastery(charm):
		icon.modulate = MASTERY_LOCKED_COLOR
	elif CharmsManager.is_mastery_active(charm):
		icon.modulate = Color.WHITE
	else:
		icon.modulate = LOCKED_COLOR

## Focus scale from the centre, clicks received by the whole cell (its icon lets them through)
func _prepare_cell(cell: Control) -> void:
	cell.pivot_offset = cell.custom_minimum_size * 0.5
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	var icon: TextureRect = _get_cell_icon(cell)
	if icon != null and icon != cell:
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Icon of a cell: the cell itself (owned charms) or its TextureRect child (slot panels)
func _get_cell_icon(cell: Control) -> TextureRect:
	if cell is TextureRect:
		return cell as TextureRect
	for child: Node in cell.get_children():
		if child is TextureRect:
			return child as TextureRect
	return null

func _get_mastery_status(index: int) -> String:
	var charm: CharmData = mastery_charms[index]
	if !CharmsManager.has_mastery(charm):
		return tr("LOADOUT_MASTERY_LOCKED") % tr(mastery_boosts[index].name)
	return tr("LOADOUT_MASTERY_ON") if CharmsManager.is_mastery_active(charm) else tr("LOADOUT_MASTERY_OFF")


func _get_part_boost(part: CarData.Car_Upgrades) -> BoostData:
	for part_boost: BoostData in ShopManager.all_car_boosts:
		if part_boost.is_car_part() and part_boost.car_part == part:
			return part_boost
	return null
