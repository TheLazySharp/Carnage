extends Control
class_name LoadoutPanel
## Loadout panel, over the roadmap: one row per owned maneuver, left/right cycles the weapon placed on it.
## Opens whenever weapons are pending (run start, survivor saved during the last raid)

const SELECTED_COLOR: Color = Color(1.0, 0.85, 0.2)
const LOCKED_COLOR: Color = Color(0.5, 0.5, 0.5)
const NAME_COLUMN_WIDTH: float = 220.0

@export var rows_container: VBoxContainer
@export var counters_label: Label

var rows: Array[ManeuverManager.Type] = []  # owned maneuvers (navigable rows)
var name_labels: Array[Label] = []
var weapon_labels: Array[Label] = []
var weapons: Array[WeaponData] = []         # weapons of the survivors on board
var selected_row: int = 0


func _ready() -> void:
	hide()


func open() -> void:
	# New weapons are pre-placed: validating without touching anything is never a loss
	LoadoutManager.auto_assign_pending()
	weapons.clear()
	for survivor: SurvivorData in SurvivorsManager.on_board_survivors:
		if survivor.weapon != null and !weapons.has(survivor.weapon):
			weapons.append(survivor.weapon)
	_build_rows()
	selected_row = 0
	_refresh()
	show()


func close() -> void:
	hide()


func _input(event: InputEvent) -> void:
	if !visible:
		return
	if event.is_action_pressed("ui_up"):
		_move_selection(-1)
	elif event.is_action_pressed("ui_down"):
		_move_selection(1)
	elif event.is_action_pressed("ui_left"):
		_cycle_weapon(-1)
	elif event.is_action_pressed("ui_right"):
		_cycle_weapon(1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_back"):
		close()
	# The map behind never reacts while the panel is open
	get_viewport().set_input_as_handled()


func _build_rows() -> void:
	for child: Node in rows_container.get_children():
		child.queue_free()
	rows.clear()
	name_labels.clear()
	weapon_labels.clear()
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
		_add_row(maneuver_type, false)
	# Locked maneuvers shown at the bottom, greyed: bought at the shop
	for maneuver_type: ManeuverManager.Type in locked:
		_add_row(maneuver_type, true)


func _add_row(maneuver_type: ManeuverManager.Type, is_locked: bool) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = ManeuverManager.get_maneuver_name(maneuver_type)
	name_label.custom_minimum_size.x = NAME_COLUMN_WIDTH
	var weapon_label: Label = Label.new()
	row.add_child(name_label)
	row.add_child(weapon_label)
	rows_container.add_child(row)
	if is_locked:
		weapon_label.text = "LOCKED"
		row.modulate = LOCKED_COLOR
	else:
		name_labels.append(name_label)
		weapon_labels.append(weapon_label)


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
		var weapon: WeaponData = LoadoutManager.get_weapon(rows[i])
		var weapon_name: String = "-" if weapon == null else InventoryManager.get_weapon_name(weapon)
		var is_selected: bool = i == selected_row
		weapon_labels[i].text = "<  %s  >" % weapon_name if is_selected else weapon_name
		var color: Color = SELECTED_COLOR if is_selected else Color.WHITE
		name_labels[i].modulate = color
		weapon_labels[i].modulate = color
	var counters: PackedStringArray = []
	for weapon: WeaponData in weapons:
		counters.append("%s %d/%d" % [InventoryManager.get_weapon_name(weapon), LoadoutManager.count_assignments(weapon), LoadoutManager.car.maneuvers_per_weapon])
	counters_label.text = "   ·   ".join(counters)
