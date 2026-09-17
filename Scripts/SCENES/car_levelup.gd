extends Control

var car : CarData = CarManager.selected_car

@onready var boost_container: GridContainer = $BoostContainer

@onready var upgrades_tag: Label = $Background/Upgrades/UpgradesTag
@export var boost_scene : PackedScene
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


var final_boosts : Array[BoostData] = []
var buttons : Array[Button] =  []
var boost_scenes : Array[Control] =  []

var nb_boost : int = 3

var focused_button : Button

func _ready() -> void:
	hide()
	if XPManager.available_upgrades <1:
		SceneManager.load_level(SceneManager.SCENES.HOME)
		return
	show()
	SignalManager.focused_entered.connect(_on_button_focused)
	SignalManager.car_level_up_upgrade.connect(_on_car_level_up)
	upgrades_tag.text = str(maxi(0,XPManager.available_upgrades))
	icon.texture = car.car_sprite
	
	var proposed_boosts : Array[BoostData] = []
	
	for i : int in nb_boost:
		var boost : BoostData = pick_boost(proposed_boosts)
		proposed_boosts.append(boost)
		
		var boost_card := boost_scene.instantiate()
		boost_container.add_child(boost_card)
		boost_card.setup(boost,false)
	
	final_boosts = proposed_boosts
	proposed_boosts.clear()
	boost_container.get_child(0).get_child(0).grab_focus()
	append_buttons()

	life_bar.max_value = StatsManager.max_life
	fuel_bar.max_value = StatsManager.max_fuel
	speed_bar.max_value = StatsManager.display_max_speed
	torque_bar.max_value = StatsManager.max_torque
	drift_bar.max_value = StatsManager.max_drift
	damages_bar.max_value = StatsManager.max_damages
	dash_dmg_bar.max_value = StatsManager.max_dash_damages
	dash_duration_bar.max_value = StatsManager.max_dash_duration
	nitro_gain_bar.max_value = StatsManager.max_nitro_up
	nitro_tank_bar.max_value = StatsManager.max_nitro_tank


	life_bar_new.max_value = StatsManager.max_life
	fuel_bar_new.max_value = StatsManager.max_fuel
	speed_bar_new.max_value = StatsManager.display_max_speed
	torque_bar_new.max_value = StatsManager.max_torque
	drift_bar_new.max_value = StatsManager.max_drift
	damages_bar_new.max_value = StatsManager.max_damages
	dash_dmg_bar_new.max_value = StatsManager.max_dash_damages
	dash_duration_bar_new.max_value = StatsManager.max_dash_duration
	nitro_gain_bar_new.max_value = StatsManager.max_nitro_up
	nitro_tank_bar_new.max_value = StatsManager.max_nitro_tank
	
	life_bar.value = car.max_life.get_value()
	fuel_bar.value = car.max_fuel.get_value()
	speed_bar.value = car.max_speed.get_value()
	torque_bar.value = car.acceleration.get_value()
	drift_bar.value = car.drift_turn_bonus.get_value()
	damages_bar.value = car.dmg.get_value()
	dash_dmg_bar.value = car.dash_dmg_bonus.get_value()
	dash_duration_bar.value = car.dash_duration.get_value()
	nitro_gain_bar.value = car.nitro_up.get_value()
	nitro_tank_bar.value = car.max_nitro.get_value()
	
	life_current.text = str(int(car.max_life.get_value()))
	fuel_tank_current.text = str(int(car.max_fuel.get_value()))
	speed_current.text = str(int(car.max_speed.get_value()))
	torque_current.text = str(int(car.acceleration.get_value()))
	drift_current.text = str(int(car.drift_turn_bonus.get_value()))
	dmg_current.text = str(int(car.dmg.get_value()))
	dash_lenght_current.text = str(int(car.dash_duration.get_value()))
	dash_dmg_current.text = str(int(car.dash_dmg_bonus.get_value()))
	nitro_tank_current.text = str(int(car.max_nitro.get_value()))
	nitro_gain_current.text = str(int(car.nitro_up.get_value()))
	
	reset_values()
	
	boost_container.get_child(0).get_child(0).grab_focus()
	append_buttons()
	_on_button_focused(boost_container.get_child(0).get_child(0))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm"):
		pass

func pick_boost(proposed_boosts : Array[BoostData]) -> BoostData:
	var attempts : int = 0
	while attempts <100:
		var boost : BoostData = ShopManager.pick_boost(ShopManager.all_car_boosts)
		if proposed_boosts.has(boost) or boost.target_ressource != boost.Target_Ressources.CAR :
			attempts += 1
			#print("boost already proposed")
			continue
		
		return boost
	push_warning("shop manager : no valid car boost found after 100 attempts")
	return ShopManager.pick_boost(ShopManager.all_car_boosts)

func _on_car_level_up() -> void:
	XPManager.available_upgrades -= 1
	upgrades_tag.text = str(XPManager.available_upgrades)
	if self.visible:
		garage_drill.play()
	if XPManager.available_upgrades > 0 :
		final_boosts.clear()
		reroll()
	else :
		SceneManager.load_level(SceneManager.SCENES.HOME)

func _on_visibility_changed() -> void:
	if self.visible : 
		#boost_container.get_child(0).get_child(0).grab_focus()
		pass

func reroll() -> void : 
	for i in range(boost_container.get_child_count() -1,-1,-1) :
		boost_container.get_child(i).queue_free()
	
	var proposed_boosts : Array[BoostData] = []
	
	for i : int in nb_boost:
		var boost : BoostData = pick_boost(proposed_boosts)
		proposed_boosts.append(boost)
		
		var boost_card := boost_scene.instantiate()
		boost_container.add_child(boost_card)
		boost_card.setup(boost,false)
		if i == 0 : 
			boost_card.get_child(0).grab_focus()
	
	final_boosts = proposed_boosts
	proposed_boosts.clear()

func _on_ignore_pressed() -> void:
	if XPManager.available_upgrades > 0 :
		XPManager.available_upgrades -= 1
		upgrades_tag.text = str(XPManager.available_upgrades)
		final_boosts.clear()
		reroll()
	else : 
		final_boosts.clear()
		SceneManager.load_level(SceneManager.SCENES.HOME)

func append_buttons() -> void :
	if boost_container.get_child_count() > 0:
		for i in boost_container.get_child_count():
			boost_scenes.append(boost_container.get_child(i))
			buttons.append(boost_container.get_child(i).get_node("Confirm"))

func show_modified_stats(boost : BoostData, target_stat_idx : int) -> float : 
	return boost.get_car_stat(boost.target_stats[target_stat_idx],car).preview_value(Modifier.new(boost.target_stats_values[target_stat_idx],boost.get_modifier_type(boost.target_stats_modifier_types[target_stat_idx]),"boost applied " + InventoryManager.get_boost_name(boost)))


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


func _on_button_focused(button : Button) -> void:
	reset_values()
	focused_button = button
	var current_boost_scn : Control = focused_button.get_parent()
	var focused_boost : BoostData = current_boost_scn.boost
	for idx in focused_boost.target_stats.size():
		if show_modified_stats(focused_boost,idx) >= focused_boost.get_car_stat(focused_boost.target_stats[idx],car).get_value():
			var stylebox_back : StyleBox = StyleBoxFlat.new()
			set_stylebox(stylebox_back, Color.DARK_GREEN)
			get_modified_bar(focused_boost,idx).add_theme_stylebox_override("fill",stylebox_back)
			
			var stylebox_front : StyleBox = StyleBoxFlat.new()
			set_stylebox(stylebox_front, FontManager.dark_yellow)
			get_current_bar(focused_boost,idx).add_theme_stylebox_override("fill",stylebox_front)
			
			get_modified_bar(focused_boost,idx).value = show_modified_stats(focused_boost,idx)
			get_current_bar(focused_boost,idx).value = focused_boost.get_car_stat(focused_boost.target_stats[idx],car).get_value()
			
			get_modified_label(focused_boost,idx).text = "> " + str(show_modified_stats(focused_boost,idx))
			get_modified_label(focused_boost,idx).add_theme_color_override("font_color",Color.GREEN)
			
		else : 
			var stylebox_back : StyleBox = StyleBoxFlat.new()
			set_stylebox(stylebox_back, Color.DARK_RED)
			get_modified_bar(focused_boost,idx).add_theme_stylebox_override("fill",stylebox_back)
			
			var stylebox_front : StyleBox = StyleBoxFlat.new()
			set_stylebox(stylebox_front, FontManager.dark_yellow)
			get_current_bar(focused_boost,idx).add_theme_stylebox_override("fill",stylebox_front)
			
			get_current_bar(focused_boost,idx).value = show_modified_stats(focused_boost,idx)
			get_modified_bar(focused_boost,idx).value = focused_boost.get_car_stat(focused_boost.target_stats[idx],car).get_value()
			
			get_modified_label(focused_boost,idx).text = "> " + str(show_modified_stats(focused_boost,idx))
			get_modified_label(focused_boost,idx).add_theme_color_override("font_color",Color.RED)
			
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
	drift_current.text = str(int(car.drift_turn_bonus.get_value()))
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
