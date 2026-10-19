extends Control
class_name LoadoutPanel
## Loadout panel, over the roadmap: one row per owned maneuver, left/right cycles the weapon placed on it.
## Opens whenever weapons are pending (run start, survivor saved during the last raid)

const SELECTED_COLOR: Color = Color(1.0, 0.85, 0.2)
const LOCKED_COLOR: Color = Color(0.5, 0.5, 0.5)
const NAME_COLUMN_WIDTH: float = 220.0

@export var rows_container: VBoxContainer
@export var counters_label: Label
@export var hint_label: Label  # optional: the controls line at the bottom of the panel
@export var hint_label2: Label  # optional: the controls line at the bottom of the panel

var rows: Array[ManeuverManager.Type] = []  # owned maneuvers (navigable rows)
var name_labels: Array[Label] = []
var weapon_labels: Array[Label] = []
var weapons: Array[WeaponData] = []         # weapons of the survivors on board
var selected_row: int = 0
var read_only: bool = false  # consultation only: nothing can be changed

func _ready() -> void:
	hide()


func open(p_read_only: bool = false) -> void:
	# Needs a started run: the car sets the per-weapon limit
	if LoadoutManager.car == null:
		push_warning("[LoadoutPanel] no run started, panel not opened")
		return
	read_only = p_read_only
	# Read-only: the full-screen root lets the mouse through to the menu around
	mouse_filter = Control.MOUSE_FILTER_IGNORE if read_only else Control.MOUSE_FILTER_STOP
	# Consulting must not change anything: pending weapons and new maneuvers wait for an editable opening
	if !read_only:
		# New weapons are pre-placed: validating without touching anything is never a loss
		LoadoutManager.auto_assign_pending()
		LoadoutManager.has_new_maneuver = false
	weapons.clear()
	for survivor: SurvivorData in SurvivorsManager.on_board_survivors:
		if survivor.weapon != null and !weapons.has(survivor.weapon):
			weapons.append(survivor.weapon)
	_build_rows()
	selected_row = 0
	_refresh()
	if hint_label != null:
		hint_label.text = tr("LOADOUT_HINT_READ_ONLY") if read_only else tr("LOADOUT_HINT_EDIT")
	show()


func close() -> void:
	hide()


func _input(event: InputEvent) -> void:
	# Read-only: display only, the menu around keeps every input (focus, buttons, mouse)
	if !visible or read_only:
		return
	if event.is_action_pressed("ui_up"):
		_move_selection(-1)
	elif event.is_action_pressed("ui_down"):
		_move_selection(1)
	elif event.is_action_pressed("ui_left"):
		_cycle_weapon(-1)
	elif event.is_action_pressed("ui_right"):
		_cycle_weapon(1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_back") or event.is_action_pressed("loadout"):
		close()
	# The scene behind never reacts while the editable panel is open
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
		var weapon_name: String = "-" if weapon == null else weapon.weapon_name
		# No selection in read-only mode: no highlight, no arrows
		var is_selected: bool = !read_only and i == selected_row
		weapon_labels[i].text = "<  %s  >" % weapon_name if is_selected else weapon_name
		var color: Color = SELECTED_COLOR if is_selected else Color.WHITE
		name_labels[i].modulate = color
		weapon_labels[i].modulate = color
	var counters: PackedStringArray = []
	for weapon: WeaponData in weapons:
		counters.append("%s %d/%d" % [weapon.weapon_name, LoadoutManager.count_assignments(weapon), LoadoutManager.car.maneuvers_per_weapon])
	counters_label.text = "   ·   ".join(counters)
