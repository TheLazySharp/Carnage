extends Control
## Car level-up: one row per car part, one cell per level. Navigate the cells (rows x levels):
## the description and the stats panel show that level. Accept / click installs the next level of a part,
## ui_back undoes the last choice. Validate leads to the shop once every upgrade is spent

## Rows are found by name: each one is a car part
const PART_BY_ROW_NAME : Dictionary[String, CarData.Car_Upgrades] = {
	"Engine": CarData.Car_Upgrades.ENGINE,
	"Tank": CarData.Car_Upgrades.TANK,
	"Front": CarData.Car_Upgrades.BUMPER,
	"Rear": CarData.Car_Upgrades.REAR_BUMPER,
	"Tires": CarData.Car_Upgrades.WHEELS,
}
const LEVEL_COUNT : int = 5

var car : CarData = CarManager.selected_car

@export var level_up_rows : VBoxContainer   # LevelUp: one HBoxContainer per part
@export var upgrade_desc_label : Label      # UpgradeDesc
@export var validate_button : Button        # former IGNORE: active once every upgrade is spent
@export var undo_hint_label : Label         # "Back: undo the last upgrade", shown when there is something to undo
@export var mastery_icon : TextureRect     # icon of the charm granted at level 5, shown on the Lvl5 cells
@export_group("Cells")
@export var obtained_color : Color = Color("740000")
@export var locked_color : Color = Color(0.18, 0.18, 0.18)
@export var focus_border_color : Color = Color.WHITE
@export var focus_border_width : int = 2
@export var mastery_font_color : Color = Color(2.5, 1.5, 0.3)

@onready var upgrades_tag: Label = $Background/Upgrades/UpgradesTag
@onready var garage_drill: AudioStreamPlayer = $Sfx/GarageDrill
@onready var icon: TextureRect = $Background/Upgrades/Icon

@onready var life_bar_new: ProgressBar = $StatsPanel/HBoxContainer/Levels/LifeBarNew
@onready var life_bar: ProgressBar = $StatsPanel/HBoxContainer/Levels/LifeBarNew/LifeBar
@onready var fuel_bar_new: ProgressBar = $StatsPanel/HBoxContainer/Levels/FuelBarNew
@onready var fuel_bar: ProgressBar = $StatsPanel/HBoxContainer/Levels/FuelBarNew/FuelBar
@onready var speed_bar_new: ProgressBar = $StatsPanel/HBoxContainer/Levels/SpeedBarNew
@onready var speed_bar: ProgressBar = $StatsPanel/HBoxContainer/Levels/SpeedBarNew/SpeedBar
@onready var torque_bar_new: ProgressBar = $StatsPanel/HBoxContainer/Levels/TorqueBarNew
@onready var torque_bar: ProgressBar = $StatsPanel/HBoxContainer/Levels/TorqueBarNew/TorqueBar
@onready var drift_bar_new: ProgressBar = $StatsPanel/HBoxContainer/Levels/DriftBarNew
@onready var drift_bar: ProgressBar = $StatsPanel/HBoxContainer/Levels/DriftBarNew/DriftBar
@onready var damages_bar_new: ProgressBar = $StatsPanel/HBoxContainer/Levels/DamagesBarNew
@onready var damages_bar: ProgressBar = $StatsPanel/HBoxContainer/Levels/DamagesBarNew/DamagesBar
@onready var dash_duration_bar_new: ProgressBar = $StatsPanel/HBoxContainer/Levels/DashDurationBarNew
@onready var dash_duration_bar: ProgressBar = $StatsPanel/HBoxContainer/Levels/DashDurationBarNew/DashDurationBar
@onready var dash_dmg_bar_new: ProgressBar = $StatsPanel/HBoxContainer/Levels/DashDmgBarNew
@onready var dash_dmg_bar: ProgressBar = $StatsPanel/HBoxContainer/Levels/DashDmgBarNew/DashDmgBar
@onready var nitro_tank_bar_new: ProgressBar = $StatsPanel/HBoxContainer/Levels/NitroTankBarNew
@onready var nitro_tank_bar: ProgressBar = $StatsPanel/HBoxContainer/Levels/NitroTankBarNew/NitroTankBar
@onready var nitro_gain_bar_new: ProgressBar = $StatsPanel/HBoxContainer/Levels/NitroGainBarNew
@onready var nitro_gain_bar: ProgressBar = $StatsPanel/HBoxContainer/Levels/NitroGainBarNew/NitroGainBar

@onready var life_current: Label = $StatsPanel/HBoxContainer/Values/Life
@onready var fuel_tank_current: Label = $StatsPanel/HBoxContainer/Values/FuelTank
@onready var speed_current: Label = $StatsPanel/HBoxContainer/Values/Speed
@onready var torque_current: Label = $StatsPanel/HBoxContainer/Values/Torque
@onready var drift_current: Label = $StatsPanel/HBoxContainer/Values/Drift
@onready var dmg_current: Label = $StatsPanel/HBoxContainer/Values/Dmg
@onready var dash_lenght_current: Label = $StatsPanel/HBoxContainer/Values/DashLenght
@onready var dash_dmg_current: Label = $StatsPanel/HBoxContainer/Values/DashDmg
@onready var nitro_tank_current: Label = $StatsPanel/HBoxContainer/Values/NitroTank
@onready var nitro_gain_current: Label = $StatsPanel/HBoxContainer/Values/NitroGain

@onready var life_new: Label = $StatsPanel/HBoxContainer/NewValues/Life
@onready var fuel_tank_new: Label = $StatsPanel/HBoxContainer/NewValues/FuelTank
@onready var speed_new: Label = $StatsPanel/HBoxContainer/NewValues/Speed
@onready var torque_new: Label = $StatsPanel/HBoxContainer/NewValues/Torque
@onready var drift_new: Label = $StatsPanel/HBoxContainer/NewValues/Drift
@onready var dmg_new: Label = $StatsPanel/HBoxContainer/NewValues/Dmg
@onready var dash_lenght_new: Label = $StatsPanel/HBoxContainer/NewValues/DashLenght
@onready var dash_dmg_new: Label = $StatsPanel/HBoxContainer/NewValues/DashDmg
@onready var nitro_tank_new: Label = $StatsPanel/HBoxContainer/NewValues/NitroTank
@onready var nitro_gain_new: Label = $StatsPanel/HBoxContainer/NewValues/NitroGain

# ---- Grid ----
var row_parts : Array[BoostData] = []   # one per row, same order as the rows
var row_cells : Array[Array] = []       # [row][level - 1] = Label
var row_bars : Array[Array] = []        # [row][level - 1] = ProgressBar before that level
var focus_row : int = 0
var focus_level : int = 1               # 1 .. LEVEL_COUNT
var on_validate : bool = false          # the selection is on the validate button

# ---- Undo (choices made on this screen only) ----
var undo_parts : Array[BoostData] = []
var undo_life_gains : PackedInt32Array = PackedInt32Array()

# ---- Cell looks, built once from the first cell ----
var style_obtained : StyleBoxFlat
var style_locked : StyleBoxFlat
var style_obtained_focus : StyleBoxFlat
var style_locked_focus : StyleBoxFlat


func _ready() -> void:
	XPManager.available_upgrades = 5
	hide()
	if XPManager.available_upgrades < 1:
		SceneManager.load_level(SceneManager.SCENES.SHOP)
		return
	show()
	BloodBars.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	icon.texture = car.car_sprite
	validate_button.text = tr("LEVELUP_VALIDATE")
	validate_button.pressed.connect(_on_validate_pressed)
	if undo_hint_label != null:
		undo_hint_label.text = tr("LEVELUP_UNDO_HINT")

	life_bar.max_value = StatsManager.max_life
	fuel_bar.max_value = StatsManager.max_fuel
	speed_bar.max_value = StatsManager.display_max_speed
	torque_bar.max_value = StatsManager.max_torque
	drift_bar.max_value = StatsManager.max_drift_score
	damages_bar.max_value = StatsManager.max_damages
	dash_dmg_bar.max_value = StatsManager.max_dash_damages
	dash_duration_bar.max_value = StatsManager.max_dash_duration
	nitro_gain_bar.max_value = StatsManager.max_nitro_up
	nitro_tank_bar.max_value = StatsManager.max_nitro_tank

	life_bar_new.max_value = StatsManager.max_life
	fuel_bar_new.max_value = StatsManager.max_fuel
	speed_bar_new.max_value = StatsManager.display_max_speed
	torque_bar_new.max_value = StatsManager.max_torque
	drift_bar_new.max_value = StatsManager.max_drift_score
	damages_bar_new.max_value = StatsManager.max_damages
	dash_dmg_bar_new.max_value = StatsManager.max_dash_damages
	dash_duration_bar_new.max_value = StatsManager.max_dash_duration
	nitro_gain_bar_new.max_value = StatsManager.max_nitro_up
	nitro_tank_bar_new.max_value = StatsManager.max_nitro_tank

	dash_dmg_bar.value = car.dash_dmg_bonus.get_value()
	dash_duration_bar.value = car.dash_duration.get_value()
	nitro_gain_bar.value = car.nitro_up.get_value()
	nitro_tank_bar.value = car.max_nitro.get_value()
	fuel_bar.value = car.max_fuel.get_value()
	_refresh_current_bars()

	_build_grid()
	# Start on the first part, on its next level
	focus_row = 0
	focus_level = _get_next_level(0)
	_refresh_grid()


# ---------------- INPUT ----------------

func _process(_delta : float) -> void:
	if Input.is_action_just_pressed("ui_up"):
		_move_focus(0, -1)
	elif Input.is_action_just_pressed("ui_down"):
		_move_focus(0, 1)
	elif Input.is_action_just_pressed("ui_left"):
		_move_focus(-1, 0)
	elif Input.is_action_just_pressed("ui_right"):
		_move_focus(1, 0)


func _input(event : InputEvent) -> void:
	# Mouse: handled by the cells and the validate button themselves
	if event is InputEventMouse:
		return
	if event.is_action_pressed("ui_accept"):
		if on_validate:
			_on_validate_pressed()
		else:
			_try_upgrade(focus_row, focus_level)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_back"):
		_undo()
		get_viewport().set_input_as_handled()


func _move_focus(dx : int, dy : int) -> void:
	if row_parts.is_empty():
		return
	if on_validate:
		if dy >= 0:
			return
		on_validate = false
		focus_row = row_parts.size() - 1
	elif dy > 0 and focus_row == row_parts.size() - 1:
		if !_can_validate():
			return
		on_validate = true
	else:
		focus_row = clampi(focus_row + dy, 0, row_parts.size() - 1)
		focus_level = clampi(focus_level + dx, 1, LEVEL_COUNT)
	_refresh_grid()


func _select_cell(row : int, level : int) -> void:
	on_validate = false
	focus_row = row
	focus_level = level
	_refresh_grid()


func _on_cell_gui_input(event : InputEvent, row : int, level : int) -> void:
	var mouse_button : InputEventMouseButton = event as InputEventMouseButton
	if mouse_button == null or !mouse_button.pressed or mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	_select_cell(row, level)
	_try_upgrade(row, level)


# ---------------- GRID ----------------

func _build_grid() -> void:
	for row_node : Node in level_up_rows.get_children():
		var part : CarData.Car_Upgrades = PART_BY_ROW_NAME.get(String(row_node.name), CarData.Car_Upgrades.N_A)
		var part_boost : BoostData = _get_part_boost(part)
		if part_boost == null:
			push_warning("[CarLevelUp] no car part for the row " + row_node.name)
			continue
		var row_index : int = row_parts.size()
		row_parts.append(part_boost)
		var cells : Array[Label] = []
		var bars : Array[ProgressBar] = []
		for level : int in range(1, LEVEL_COUNT + 1):
			var cell : Label = row_node.get_node("Lvl%d" % level) as Label
			var bar_name : String = "ProgressBar" if level == 1 else "ProgressBar%d" % level
			var bar : ProgressBar = row_node.get_node(bar_name) as ProgressBar
			cell.mouse_filter = Control.MOUSE_FILTER_STOP
			cell.gui_input.connect(_on_cell_gui_input.bind(row_index, level))
			cell.mouse_entered.connect(_select_cell.bind(row_index, level))
			bar.min_value = 0.0
			bar.max_value = 100.0
			if level == LEVEL_COUNT:
				cell.add_theme_color_override("font_color", mastery_font_color)
			cells.append(cell)
			bars.append(bar)
		row_cells.append(cells)
		row_bars.append(bars)
		var name_label : Label = row_node.get_node_or_null("ColorRect/Icon/Label") as Label
		if name_label != null:
			name_label.text = tr(part_boost.name)
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
	for row : int in row_parts.size():
		var level : int = car.get_part_level(row_parts[row].car_part)
		for i : int in LEVEL_COUNT:
			var obtained : bool = i < level
			var focused : bool = !on_validate and row == focus_row and i + 1 == focus_level
			var style : StyleBoxFlat
			if obtained:
				style = style_obtained_focus if focused else style_obtained
			else:
				style = style_locked_focus if focused else style_locked
			(row_cells[row][i] as Label).add_theme_stylebox_override("normal", style)
			(row_bars[row][i] as ProgressBar).value = 100.0 if obtained else 0.0
	upgrades_tag.text = str(maxi(0, XPManager.available_upgrades))
	validate_button.disabled = !_can_validate()
	if on_validate:
		validate_button.grab_focus()
	elif validate_button.has_focus():
		validate_button.release_focus()
	if undo_hint_label != null:
		undo_hint_label.visible = !undo_parts.is_empty()
	_refresh_details()


## Description and stats preview of the focused cell
func _refresh_details() -> void:
	reset_values()
	if mastery_icon != null:
		mastery_icon.hide()
	if on_validate or row_parts.is_empty():
		upgrade_desc_label.text = ""
		return
	var part_boost : BoostData = row_parts[focus_row]
	var current_level : int = car.get_part_level(part_boost.car_part)
	var lines : PackedStringArray = []
	lines.append("%s - %s %d" % [tr(part_boost.name), tr("PART_LEVEL"), focus_level])
	var bonus : float = part_boost.get_next_bonus(focus_level - 1)
	for target_stat : BoostData.Target_Stats in part_boost.target_stats:
		lines.append("%s + %d %%" % [part_boost.get_stat_string(target_stat), roundi(bonus * 100.0)])
	# Level 5 cell: the charm granted by the part, shown even while the level is locked
	if focus_level == LEVEL_COUNT and part_boost.mastery_charm != null:
		var charm : CharmData = part_boost.mastery_charm
		lines.append("")
		lines.append(tr("MASTERY_GET") % InventoryManager.get_charm_name(charm))
		lines.append(tr(charm.description))
		if mastery_icon != null:
			mastery_icon.texture = charm.icon
			mastery_icon.show()
	lines.append("")
	if focus_level <= current_level:
		lines.append(tr("LEVELUP_OWNED"))
	elif focus_level == current_level + 1:
		lines.append(tr("LEVELUP_AVAILABLE") if XPManager.available_upgrades > 0 else tr("LEVELUP_NO_UPGRADE"))
	else:
		lines.append(tr("LEVELUP_LOCKED"))
	upgrade_desc_label.text = "\n".join(lines)
	if focus_level > current_level:
		_show_stats_preview(part_boost, current_level, focus_level)


## Stats panel with the part raised from current_level to target_level
func _show_stats_preview(part_boost : BoostData, current_level : int, target_level : int) -> void:
	var preview_mod : Modifier = part_boost.make_part_preview_modifier(current_level, target_level)
	for idx : int in part_boost.target_stats.size():
		var modified_bar : ProgressBar = get_modified_bar(part_boost, idx)
		var current_bar : ProgressBar = get_current_bar(part_boost, idx)
		var modified_label : Label = get_modified_label(part_boost, idx)
		# Stats without their own row (combo gain, drift charge, perfect hit power): shown through the drift score
		if modified_bar == null or current_bar == null or modified_label == null:
			continue
		var stat : Statistic = part_boost.get_car_stat(part_boost.target_stats[idx], car)
		_show_bar_preview(current_bar, modified_bar, modified_label, stat.get_value(), stat.preview_value(preview_mod))
	var current_drift : float = StatsManager.get_drift_score(car)
	var new_drift : float = StatsManager.get_drift_score(car, part_boost, target_level)
	if !is_equal_approx(current_drift, new_drift):
		_show_bar_preview(drift_bar, drift_bar_new, drift_new, current_drift, new_drift)


# ---------------- UPGRADE / UNDO / VALIDATE ----------------

## Only the next level of a part, and only with an upgrade left
func _try_upgrade(row : int, level : int) -> void:
	if row < 0 or row >= row_parts.size():
		return
	var part_boost : BoostData = row_parts[row]
	if level != car.get_part_level(part_boost.car_part) + 1 or XPManager.available_upgrades <= 0:
		return
	var base_max_life : int = int(car.max_life.get_value())
	if !car.upgrade_part(part_boost):
		return
	# A bigger blood tank fills up by the same amount (given back on undo)
	var life_gain : int = int(car.max_life.get_value()) - base_max_life
	car.current_life += life_gain
	undo_parts.append(part_boost)
	undo_life_gains.append(life_gain)
	XPManager.available_upgrades -= 1
	garage_drill.play()
	SignalManager.stats_updated.emit()
	_refresh_current_bars()
	# Last upgrade spent: the selection moves to the validate button
	if _can_validate():
		on_validate = true
	_refresh_grid()


func _undo() -> void:
	if undo_parts.is_empty():
		return
	var part_boost : BoostData = undo_parts.pop_back()
	var life_gain : int = undo_life_gains[undo_life_gains.size() - 1]
	undo_life_gains.resize(undo_life_gains.size() - 1)
	if !car.downgrade_part(part_boost):
		return
	car.current_life = maxi(car.current_life - life_gain, 1)
	XPManager.available_upgrades += 1
	SignalManager.stats_updated.emit()
	_refresh_current_bars()
	# Back on the cell just undone
	on_validate = false
	focus_row = row_parts.find(part_boost)
	focus_level = car.get_part_level(part_boost.car_part) + 1
	_refresh_grid()


func _on_validate_pressed() -> void:
	if !_can_validate():
		return
	# Every part maxed with upgrades left: nothing to spend them on
	XPManager.available_upgrades = 0
	set_process(false)
	SceneManager.load_level(SceneManager.SCENES.SHOP)


## Every upgrade spent, or nothing left to raise
func _can_validate() -> bool:
	return XPManager.available_upgrades <= 0 or !_has_upgrade_left()


func _has_upgrade_left() -> bool:
	for part_boost : BoostData in row_parts:
		if car.get_part_level(part_boost.car_part) < part_boost.get_max_level():
			return true
	return false


func _get_next_level(row : int) -> int:
	if row >= row_parts.size():
		return 1
	return clampi(car.get_part_level(row_parts[row].car_part) + 1, 1, LEVEL_COUNT)


func _get_part_boost(part : CarData.Car_Upgrades) -> BoostData:
	for part_boost : BoostData in ShopManager.all_car_boosts:
		if part_boost.is_car_part() and part_boost.car_part == part:
			return part_boost
	return null


# ---------------- STATS PANEL ----------------

## Current values after an upgrade or an undo
func _refresh_current_bars() -> void:
	life_bar.value = car.max_life.get_value()
	speed_bar.value = car.max_speed.get_value()
	torque_bar.value = car.acceleration.get_value()
	drift_bar.value = StatsManager.get_drift_score(car)
	damages_bar.value = car.dmg.get_value()


func get_modified_bar(boost : BoostData, target_stat_idx : int) -> ProgressBar:
	match boost.target_stats[target_stat_idx]:
		boost.Target_Stats.ACCELERATION:
			return torque_bar_new
		boost.Target_Stats.MAX_SPEED:
			return speed_bar_new
		boost.Target_Stats.MAX_LIFE:
			return life_bar_new
		boost.Target_Stats.CAR_DMG:
			return damages_bar_new
		boost.Target_Stats.MAX_FUEL:
			return fuel_bar_new
		boost.Target_Stats.DRIFT_TURN_BONUS:
			return drift_bar_new
		boost.Target_Stats.DASH_DMG_BONUS:
			return dash_dmg_bar_new
		boost.Target_Stats.DASH_DURATION:
			return dash_duration_bar_new
		boost.Target_Stats.NITRO_UP:
			return nitro_gain_bar_new
		boost.Target_Stats.MAX_NITRO:
			return nitro_tank_bar_new
	return null


func get_modified_label(boost : BoostData, target_stat_idx : int) -> Label:
	match boost.target_stats[target_stat_idx]:
		boost.Target_Stats.ACCELERATION:
			return torque_new
		boost.Target_Stats.MAX_SPEED:
			return speed_new
		boost.Target_Stats.MAX_LIFE:
			return life_new
		boost.Target_Stats.CAR_DMG:
			return dmg_new
		boost.Target_Stats.MAX_FUEL:
			return fuel_tank_new
		boost.Target_Stats.DRIFT_TURN_BONUS:
			return drift_new
		boost.Target_Stats.DASH_DMG_BONUS:
			return dash_dmg_new
		boost.Target_Stats.DASH_DURATION:
			return dash_lenght_new
		boost.Target_Stats.NITRO_UP:
			return nitro_gain_new
		boost.Target_Stats.MAX_NITRO:
			return nitro_tank_new
	return null


func get_current_bar(boost : BoostData, target_stat_idx : int) -> ProgressBar:
	match boost.target_stats[target_stat_idx]:
		boost.Target_Stats.ACCELERATION:
			return torque_bar
		boost.Target_Stats.MAX_SPEED:
			return speed_bar
		boost.Target_Stats.MAX_LIFE:
			return life_bar
		boost.Target_Stats.CAR_DMG:
			return damages_bar
		boost.Target_Stats.MAX_FUEL:
			return fuel_bar
		boost.Target_Stats.DRIFT_TURN_BONUS:
			return drift_bar
		boost.Target_Stats.DASH_DMG_BONUS:
			return dash_dmg_bar
		boost.Target_Stats.DASH_DURATION:
			return dash_duration_bar
		boost.Target_Stats.NITRO_UP:
			return nitro_gain_bar
		boost.Target_Stats.MAX_NITRO:
			return nitro_tank_bar
	return null


## Colors and fills one row of the stats panel: green when the value rises, red when it drops
func _show_bar_preview(current_bar : ProgressBar, modified_bar : ProgressBar, modified_label : Label, current_value : float, new_value : float) -> void:
	var stylebox_front : StyleBox = StyleBoxFlat.new()
	set_stylebox(stylebox_front, FontManager.dark_yellow)
	current_bar.add_theme_stylebox_override("fill", stylebox_front)

	var stylebox_back : StyleBox = StyleBoxFlat.new()
	if new_value >= current_value:
		set_stylebox(stylebox_back, Color.DARK_GREEN)
		modified_bar.value = new_value
		current_bar.value = current_value
		modified_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		set_stylebox(stylebox_back, Color.DARK_RED)
		current_bar.value = new_value
		modified_bar.value = current_value
		modified_label.add_theme_color_override("font_color", Color.RED)
	modified_bar.add_theme_stylebox_override("fill", stylebox_back)
	modified_label.text = "> " + str(roundi(new_value))


func reset_values() -> void : 
	life_bar_new.value = life_bar.value
	fuel_bar_new.value = fuel_bar.value
	speed_bar_new.value = speed_bar.value
	torque_bar_new.value = torque_bar.value
	drift_bar_new.value = drift_bar.value
	damages_bar_new.value = damages_bar.value
	dash_dmg_bar_new.value = dash_dmg_bar.value
	dash_duration_bar_new.value = dash_duration_bar.value
	nitro_gain_bar_new.value = nitro_gain_bar.value
	nitro_tank_bar_new.value = nitro_tank_bar.value
	
	life_current.text = str(int(car.max_life.get_value()))
	fuel_tank_current.text = str(int(car.max_fuel.get_value()))
	speed_current.text = str(int(car.max_speed.get_value()))
	torque_current.text = str(int(car.acceleration.get_value()))
	drift_current.text = str(roundi(StatsManager.get_drift_score(car)))
	dmg_current.text = str(int(car.dmg.get_value()))
	dash_lenght_current.text = str(int(car.dash_duration.get_value()))
	dash_dmg_current.text = str(int(car.dash_dmg_bonus.get_value()))
	nitro_tank_current.text = str(int(car.max_nitro.get_value()))
	nitro_gain_current.text = str(int(car.nitro_up.get_value()))
	
	life_new.text = ""
	fuel_tank_new.text = ""
	speed_new.text = ""
	torque_new.text = ""
	drift_new.text = ""
	dmg_new.text = ""
	dash_lenght_new.text = ""
	dash_dmg_new.text = ""
	nitro_tank_new.text = ""
	nitro_gain_new.text = ""


func set_stylebox(sb : StyleBox, color : Color) -> void:
	sb.bg_color = color
	sb.skew = Vector2(0.6,0)
	sb.draw_center = true
	sb.corner_detail = 8
