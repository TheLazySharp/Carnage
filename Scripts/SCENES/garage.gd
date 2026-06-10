extends Control

var car := CarManager.selected_car
	#----------TEST---------------#
#var car : CarData


@onready var entrance: Control = $Entrance
@onready var upgrades: Control = $Upgrades
@onready var back: Button = $Entrance/EntranceButtons/Back
@onready var confirm: Button = $Upgrades/UpgradeButtons/Confirm


#-----------------ENTRANCE -------------------#
#CAR
@onready var car_name: Label = $Entrance/Repair/CarName
@onready var car_icon: TextureRect = $Entrance/Repair/CarIcon
@onready var repair_button: Button = $Entrance/RepairButton


#-----------------UPGRADES -------------------#
#STATS NUMBERS
@onready var fuel_lvl: Label = $Upgrades/StatPanel/HBoxContainer/Levels/Fuel_lvl
@onready var speed_lvl: Label = $Upgrades/StatPanel/HBoxContainer/Levels/Speed_lvl
@onready var torque_lvl: Label = $Upgrades/StatPanel/HBoxContainer/Levels/Torque_lvl
@onready var dmg_lvl: Label = $Upgrades/StatPanel/HBoxContainer/Levels/Dmg_lvl
@onready var drift_lvl: Label = $Upgrades/StatPanel/HBoxContainer/Levels/Drift_lvl
@onready var tires_lvl: Label = $Upgrades/StatPanel/HBoxContainer/Levels/Tires_lvl
@onready var dash_lvl: Label = $Upgrades/StatPanel/HBoxContainer/Levels/Dash_lvl
@onready var crit_lvl: Label = $Upgrades/StatPanel/HBoxContainer/Levels/Crit_lvl


#STATS UPGRADES NUMBERS
@onready var fuel_upgrade: Label = $Upgrades/StatPanel/HBoxContainer/Upgrade/Fuel_upgrade
@onready var speed_upgrade: Label = $Upgrades/StatPanel/HBoxContainer/Upgrade/Speed_upgrade
@onready var torque_upgrade: Label = $Upgrades/StatPanel/HBoxContainer/Upgrade/Torque_upgrade
@onready var dmg_upgrade: Label = $Upgrades/StatPanel/HBoxContainer/Upgrade/Dmg_upgrade
@onready var drift_upgrade: Label = $Upgrades/StatPanel/HBoxContainer/Upgrade/Drift_upgrade
@onready var tires_upgrade: Label = $Upgrades/StatPanel/HBoxContainer/Upgrade/Tires_upgrade
@onready var dash_upgrade: Label = $Upgrades/StatPanel/HBoxContainer/Upgrade/Dash_upgrade
@onready var crit_upgrade: Label = $Upgrades/StatPanel/HBoxContainer/Upgrade/Crit_upgrade


var base_fuel: int
var base_max_speed: int
var base_torque: int
var base_dmg: int
var base_drift: float
var base_tires : int
var base_dash : float
var base_crit : float

var engine_base_lvl: int
var turbo_base_lvl: int
var shield_base_lvl: int
var carbon_base_lvl: int
var tank_base_lvl: int
var nitro_base_lvl: int
var wheels_base_lvl: int
var bumper_base_lvl: int

var upgraded_stats : Array[Statistic]
var total_upgrade_cost:=0
@onready var base_available_upgrades : int


#GEAR PARTS
@onready var total_q: Label = $Upgrades/HBoxContainer/GearPanel/VBoxContainer2/TotalQ
@onready var requested_q: Label = $Upgrades/HBoxContainer/GearPanel/VBoxContainer2/RequestedQ
@onready var cost_q: Label = $Upgrades/HBoxContainer/GearPanel/VBoxContainer2/CostQ

#LEVELS
@onready var current_lvl: Label = $Upgrades/HBoxContainer/LvlPanel/VBoxContainer2/CurrentLvlQ
@onready var availupgrade: Label = $Upgrades/HBoxContainer/LvlPanel/VBoxContainer2/AvailupgradeQ

#MECHANICS LEVELS LABELS
@onready var engine_lvl: Label = $Upgrades/UpgradePanel/VBoxContainer/Engine/Lvl/EngineLvl
@onready var turbo_lvl: Label = $Upgrades/UpgradePanel/VBoxContainer/Turbo/Lvl/TurboLvl
@onready var shield_lvl: Label = $Upgrades/UpgradePanel/VBoxContainer/Shield/Lvl/ShieldLvl
@onready var carbon_lvl: Label = $Upgrades/UpgradePanel/VBoxContainer/Carbon/Lvl/CarbonLvl
@onready var tank_lvl: Label = $Upgrades/UpgradePanel/VBoxContainer/Tank/Lvl/TankLvl
@onready var wheels_lvl: Label = $Upgrades/UpgradePanel/VBoxContainer/Wheels/Lvl/WheelsLvl
@onready var nitro_lvl: Label = $Upgrades/UpgradePanel/VBoxContainer/Dash/Lvl/NitroLvl
@onready var bumper_lvl: Label = $Upgrades/UpgradePanel/VBoxContainer/Crit/Lvl/BumperLvl


#MECHANICS BUTTONS
@onready var engine_up: Button = $Upgrades/UpgradePanel/VBoxContainer/Engine/ButtonUp/EngineUp
@onready var turbo_up: Button = $Upgrades/UpgradePanel/VBoxContainer/Turbo/ButtonUp/TurboUp
@onready var shield_up: Button = $Upgrades/UpgradePanel/VBoxContainer/Shield/ButtonUp/ShieldUp
@onready var carbon_up: Button = $Upgrades/UpgradePanel/VBoxContainer/Carbon/ButtonUp/CarbonUp
@onready var tank_up: Button = $Upgrades/UpgradePanel/VBoxContainer/Tank/ButtonUp/TankUp
@onready var wheel_up: Button = $Upgrades/UpgradePanel/VBoxContainer/Wheels/ButtonUp/WheelUp
@onready var nitro_up: Button = $Upgrades/UpgradePanel/VBoxContainer/Dash/ButtonUp/NitroUp
@onready var bumper_up: Button = $Upgrades/UpgradePanel/VBoxContainer/Crit/ButtonUp/BumperUp

@onready var engine_down: Button = $Upgrades/UpgradePanel/VBoxContainer/Engine/ButtonDown/EngineDown
@onready var turbo_down: Button = $Upgrades/UpgradePanel/VBoxContainer/Turbo/ButtonDown/TurboDown
@onready var shield_down: Button = $Upgrades/UpgradePanel/VBoxContainer/Shield/ButtonDown/ShieldDown
@onready var carbon_down: Button = $Upgrades/UpgradePanel/VBoxContainer/Carbon/ButtonDown/CarbonDown
@onready var tank_down: Button = $Upgrades/UpgradePanel/VBoxContainer/Tank/ButtonDown/TankDown
@onready var wheel_down: Button = $Upgrades/UpgradePanel/VBoxContainer/Wheels/ButtonDown/WheelDown
@onready var nitro_down: Button = $Upgrades/UpgradePanel/VBoxContainer/Dash/ButtonDown/NitroDown
@onready var bumper_down: Button = $Upgrades/UpgradePanel/VBoxContainer/Crit/ButtonDown/BumperDown

var engine_modifier : Modifier
var turbo_modifier : Modifier
var shield_modifier_pos : Modifier
var shield_modifier_neg : Modifier
var carbon_modifier_pos : Modifier
var carbon_modifier_neg : Modifier
var tank_modifier : Modifier
var wheel_modifier : Modifier
var nitro_modifier : Modifier
var bumper_modifier : Modifier


func _ready() -> void:
	##----------TEST---------------#
	#CarManager.selected_car = CarManager.cars[0]
	#car = CarManager.selected_car
	#XPManager.current_level = 4
	#InventoryManager.auto_parts = 2000
	
	engine_modifier = Modifier.new(10,Modifier.Type.FLAT,"engine_mod",0)
	turbo_modifier = Modifier.new(10,Modifier.Type.FLAT,"acceleration_mod",0)
	shield_modifier_pos = Modifier.new(5,Modifier.Type.FLAT,"shield_pos_mod",0)
	shield_modifier_neg = Modifier.new(-5,Modifier.Type.FLAT,"shield_neg_mod",0)
	carbon_modifier_pos = Modifier.new(5,Modifier.Type.FLAT,"carbon_pos_mod",0)
	carbon_modifier_neg = Modifier.new(-5,Modifier.Type.FLAT,"carbon_neg_mod",0)
	tank_modifier = Modifier.new(10,Modifier.Type.FLAT,"tank_mod",0)
	wheel_modifier = Modifier.new(2,Modifier.Type.FLAT,"wheels_mod",0)
	nitro_modifier = Modifier.new(0.2,Modifier.Type.FLAT,"nitro_mod",0)
	bumper_modifier = Modifier.new(0.5,Modifier.Type.FLAT,"nitro_mod",0) #applied on dash_dmh_bonus which is applied has a percent multiplier -> add 50%

	base_fuel = roundi(car.max_life.get_value())
	base_max_speed = roundi(car.display_max_speed.get_value())
	base_torque = roundi(car.acceleration.get_value())
	base_dmg = roundi(car.dmg.get_value())
	base_drift = car.drift_turn_bonus.get_value() + car.turn_speed
	base_tires = roundi(car.nitro_up.get_value())
	base_dash = car.dash_duration.get_value()
	base_crit = car.dash_dmg_bonus.get_value()
	
	engine_base_lvl = car.engine_lvl
	turbo_base_lvl = car.turbo_lvl
	shield_base_lvl = car.shield_lvl
	carbon_base_lvl = car.carbon_lvl
	tank_base_lvl = car.tank_lvl
	wheels_base_lvl = car.wheels_lvl
	nitro_base_lvl = car.nitro_lvl
	bumper_base_lvl = car.bumper_lvl
	
	car_name.text = car.car_name
	car_icon.texture = car.car_sprite
	
	current_lvl.text = str(XPManager.current_level)
	availupgrade.text = str(XPManager.available_upgrades)
	
	total_q.text = str(InventoryManager.auto_parts)
	requested_q.text = str(XPManager.upgrade_cost)
	cost_q.text = str(total_upgrade_cost)
	
	entrance.show()
	upgrades.hide()
	repair_button.grab_focus()
	
	update_stats()
	base_available_upgrades = XPManager.available_upgrades
	
	print("total upgrades : ",XPManager.total_upgrades," / available upgrades : ", XPManager.available_upgrades)


func _process(_delta: float) -> void:
	if !upgrade_ok():
		total_q.add_theme_color_override("font_color",Color.RED)
	else : total_q.add_theme_color_override("font_color",Color.WHITE)
	total_q.text = str(InventoryManager.auto_parts)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_back"):
		if entrance.visible and !upgrades.visible:
			SceneManager.load_level(SceneManager.SCENES.END_DAY)
		if !entrance.visible and upgrades.visible:
			entrance.show()
			upgrades.hide()
			back.grab_focus()
	if event.is_action_pressed("confirm"):
		if !entrance.visible and upgrades.visible:
			confirm.grab_focus()

func update_stats() -> void:
	XPManager.update_upgrades()

	fuel_lvl.text = str(roundi(car.max_life.get_value()))
	speed_lvl.text = str(roundi(car.display_max_speed.get_value()))
	torque_lvl.text = str(roundi(car.acceleration.get_value()))
	dmg_lvl.text = str(roundi(car.dmg.get_value()))
	drift_lvl.text = str(car.drift_turn_bonus.get_value() + car.turn_speed)
	tires_lvl.text = str(roundi(car.nitro_up.get_value()))
	dash_lvl.text = str(car.dash_duration.get_value())
	crit_lvl.text = str(car.dash_dmg_bonus.get_value())
	
	fuel_upgrade.text = str(roundi(car.max_life.get_value() - base_fuel))
	speed_upgrade.text = str(roundi(car.display_max_speed.get_value() - base_max_speed))
	torque_upgrade.text = str(roundi(car.acceleration.get_value() - base_torque))
	dmg_upgrade.text = str(roundi(car.dmg.get_value() - base_dmg))
	drift_upgrade.text = str(car.drift_turn_bonus.get_value() + car.turn_speed - base_drift)
	tires_upgrade.text = str(roundi(car.nitro_up.get_value() - base_tires))
	dash_upgrade.text = str(car.dash_duration.get_value() - base_dash)
	crit_upgrade.text = str(car.dash_dmg_bonus.get_value() - base_crit)
	
	engine_lvl.text = "Lvl " + str(car.engine_lvl)
	turbo_lvl.text = "Lvl " + str(car.turbo_lvl)
	shield_lvl.text = "Lvl " + str(car.shield_lvl)
	carbon_lvl.text = "Lvl " + str(car.carbon_lvl)
	tank_lvl.text = "Lvl " + str(car.tank_lvl)
	wheels_lvl.text = "Lvl " + str(car.wheels_lvl)
	nitro_lvl.text = "Lvl " + str(car.nitro_lvl)
	bumper_lvl.text = "Lvl " + str(car.bumper_lvl)
	
	availupgrade.text = str(XPManager.available_upgrades)
	requested_q.text = str(XPManager.upgrade_cost)
	cost_q.text = str(total_upgrade_cost)
	total_q.text = str(InventoryManager.auto_parts - total_upgrade_cost)

func _on_engine_up_pressed() -> void:
	if XPManager.available_upgrades > 0 and engine_base_lvl <= car.engine_lvl and upgrade_ok():
		car.engine_lvl +=1
		total_upgrade_cost += XPManager.cost_formula(0)
		XPManager.total_upgrades +=1
		
		car.max_speed.add_modifier(engine_modifier)
		car.display_max_speed.add_modifier(engine_modifier)
		update_stats()

func _on_engine_down_pressed() -> void:
	if XPManager.available_upgrades >= 0 and engine_base_lvl < car.engine_lvl and downgrade_ok():
		car.engine_lvl -=1
		XPManager.total_upgrades -=1
		total_upgrade_cost -= XPManager.cost_formula(0)
		
		car.max_speed.remove_modifier(engine_modifier)
		car.display_max_speed.remove_modifier(engine_modifier)
		update_stats()

func _on_turbo_up_pressed() -> void:
	if XPManager.available_upgrades > 0 and turbo_base_lvl <= car.turbo_lvl and upgrade_ok():
		car.turbo_lvl +=1
		total_upgrade_cost += XPManager.cost_formula(0)
		XPManager.total_upgrades +=1
		
		car.acceleration.add_modifier(turbo_modifier)
		update_stats()

func _on_turbo_down_pressed() -> void:
	if XPManager.available_upgrades >= 0 and turbo_base_lvl < car.turbo_lvl and downgrade_ok():
		car.turbo_lvl -=1
		XPManager.total_upgrades -=1
		total_upgrade_cost -= XPManager.cost_formula(0)
		
		car.acceleration.remove_modifier(turbo_modifier)
		update_stats()

func _on_shield_up_pressed() -> void:
	if XPManager.available_upgrades > 0 and shield_base_lvl <= car.shield_lvl and upgrade_ok():
		car.shield_lvl +=1
		total_upgrade_cost += XPManager.cost_formula(0)
		XPManager.total_upgrades +=1
		
		car.max_life.add_modifier(shield_modifier_pos)
		car.dmg.add_modifier(shield_modifier_pos)
		car.acceleration.add_modifier(shield_modifier_neg)
		update_stats()

func _on_shield_down_pressed() -> void:
	if XPManager.available_upgrades >= 0 and shield_base_lvl < car.shield_lvl and downgrade_ok():
		car.shield_lvl -=1
		XPManager.total_upgrades -=1
		total_upgrade_cost -= XPManager.cost_formula(0)
		
		car.max_life.remove_modifier(shield_modifier_pos)
		car.dmg.remove_modifier(shield_modifier_pos)
		car.acceleration.remove_modifier(shield_modifier_neg)
		update_stats()

func _on_carbon_up_pressed() -> void:
	if XPManager.available_upgrades > 0 and carbon_base_lvl <= car.carbon_lvl and upgrade_ok():
		car.carbon_lvl +=1
		total_upgrade_cost += XPManager.cost_formula(0)
		XPManager.total_upgrades +=1
		
		car.acceleration.add_modifier(carbon_modifier_pos)
		car.max_life.add_modifier(carbon_modifier_neg)
		update_stats()

func _on_carbon_down_pressed() -> void:
	if XPManager.available_upgrades >= 0 and carbon_base_lvl < car.carbon_lvl and downgrade_ok():
		car.carbon_lvl -=1
		XPManager.total_upgrades -=1
		total_upgrade_cost -= XPManager.cost_formula(0)
		
		car.acceleration.remove_modifier(carbon_modifier_pos)
		car.max_life.remove_modifier(carbon_modifier_neg)
		update_stats()

func _on_tank_up_pressed() -> void:
	if XPManager.available_upgrades > 0 and tank_base_lvl <= car.tank_lvl and upgrade_ok():
		car.tank_lvl +=1
		total_upgrade_cost += XPManager.cost_formula(0)
		XPManager.total_upgrades +=1
		
		car.max_life.add_modifier(tank_modifier)
		update_stats()

func _on_tank_down_pressed() -> void:
	if XPManager.available_upgrades >= 0 and tank_base_lvl < car.tank_lvl and downgrade_ok():
		car.tank_lvl -=1
		XPManager.total_upgrades -=1
		total_upgrade_cost -= XPManager.cost_formula(0)
		
		car.max_life.remove_modifier(tank_modifier)
		update_stats()

func _on_wheel_up_pressed() -> void:
	if XPManager.available_upgrades > 0 and wheels_base_lvl <= car.wheels_lvl and upgrade_ok():
		car.wheels_lvl +=1
		total_upgrade_cost += XPManager.cost_formula(0)
		XPManager.total_upgrades +=1
		
		car.nitro_up.add_modifier(wheel_modifier)
		update_stats()

func _on_wheel_down_pressed() -> void:
	if XPManager.available_upgrades >= 0 and wheels_base_lvl < car.wheels_lvl and downgrade_ok():
		car.wheels_lvl -=1
		XPManager.total_upgrades -=1
		total_upgrade_cost -= XPManager.cost_formula(0)
		
		car.nitro_up.remove_modifier(wheel_modifier)
		update_stats()

func _on_nitro_up_pressed() -> void:
	if XPManager.available_upgrades > 0 and nitro_base_lvl <= car.nitro_lvl and upgrade_ok():
		car.nitro_lvl +=1
		total_upgrade_cost += XPManager.cost_formula(0)
		XPManager.total_upgrades +=1
		
		car.dash_duration.add_modifier(nitro_modifier)
		update_stats()

func _on_nitro_down_pressed() -> void:
	if XPManager.available_upgrades >= 0 and nitro_base_lvl < car.nitro_lvl and downgrade_ok():
		car.nitro_lvl -=1
		XPManager.total_upgrades -=1
		total_upgrade_cost -= XPManager.cost_formula(0)
		
		car.dash_duration.remove_modifier(nitro_modifier)
		update_stats()

func _on_bumper_up_pressed() -> void:
	if XPManager.available_upgrades > 0 and bumper_base_lvl <= car.bumper_lvl and upgrade_ok():
		car.bumper_lvl +=1
		total_upgrade_cost += XPManager.cost_formula(0)
		XPManager.total_upgrades +=1
		
		car.dash_dmg_bonus.add_modifier(bumper_modifier)
		update_stats()

func _on_bumper_down_pressed() -> void:
	if XPManager.available_upgrades >= 0 and bumper_base_lvl < car.bumper_lvl and downgrade_ok():
		car.bumper_lvl -=1
		XPManager.total_upgrades -=1
		total_upgrade_cost -= XPManager.cost_formula(0)
		
		car.dash_dmg_bonus.remove_modifier(bumper_modifier)
		update_stats()

func upgrade_ok() -> bool:
	if InventoryManager.auto_parts - total_upgrade_cost >= XPManager.upgrade_cost:
		return true
	else : return false

func downgrade_ok() -> bool:
	if base_available_upgrades > XPManager.available_upgrades:
		return true
	else : return false

func _on_confirm_pressed() -> void:
	pass

func _on_back_pressed() -> void:
	SceneManager.load_level(end_of_day_scene)

func _on_upgrade_button_pressed() -> void:
	entrance.hide()
	upgrades.show()
	engine_up.grab_focus()

func _on_upgrades_confirm_pressed() -> void:
	InventoryManager.auto_parts -= total_upgrade_cost
	total_upgrade_cost = 0
	base_available_upgrades = XPManager.available_upgrades
	car.current_life += int(car.max_life.get_value() - base_fuel)
	
	
	base_fuel = int(car.max_life.get_value())
	base_max_speed = int(car.display_max_speed.get_value())
	base_torque = int(car.acceleration.get_value())
	base_dmg = int(car.dmg.get_value())
	base_drift = car.drift_turn_bonus.get_value() + car.turn_speed
	base_tires = int(car.nitro_up.get_value())
	base_dash = car.dash_duration.get_value()
	base_crit = car.dash_dmg_bonus.get_value()
	
	engine_base_lvl = car.engine_lvl
	turbo_base_lvl = car.turbo_lvl
	shield_base_lvl = car.shield_lvl
	carbon_base_lvl = car.carbon_lvl
	tank_base_lvl = car.tank_lvl
	wheels_base_lvl = car.wheels_lvl
	nitro_base_lvl = car.nitro_lvl
	bumper_base_lvl = car.bumper_lvl
	
	update_stats()
	entrance.show()
	upgrades.hide()
	back.grab_focus()

func _on_upgrades_back_pressed() -> void:
	entrance.show()
	upgrades.hide()
	back.grab_focus()
