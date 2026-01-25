extends Control

var car := CarManager.selected_car
	#----------TEST---------------#
#var car : CarData

var end_oy_day_scene:= "uid://dkpvtoel7hhai"

#CAR
@onready var car_name: Label = $StatPanel/CarName
@onready var car_icon: TextureRect = $StatPanel/CarIcon

#STATS NUMBERS
@onready var fuel_lvl: Label = $StatPanel/HBoxContainer/Levels/Fuel_lvl
@onready var speed_lvl: Label = $StatPanel/HBoxContainer/Levels/Speed_lvl
@onready var torque_lvl: Label = $StatPanel/HBoxContainer/Levels/Torque_lvl
@onready var dmg_lvl: Label = $StatPanel/HBoxContainer/Levels/Dmg_lvl
@onready var drift_lvl: Label = $StatPanel/HBoxContainer/Levels/Drift_lvl


#STATS UPGRADES NUMBERS
@onready var fuel_upgrade: Label = $StatPanel/HBoxContainer/Upgrade/Fuel_upgrade
@onready var speed_upgrade: Label = $StatPanel/HBoxContainer/Upgrade/Speed_upgrade
@onready var torque_upgrade: Label = $StatPanel/HBoxContainer/Upgrade/Torque_upgrade
@onready var dmg_upgrade: Label = $StatPanel/HBoxContainer/Upgrade/Dmg_upgrade
@onready var drift_upgrade: Label = $StatPanel/HBoxContainer/Upgrade/Drift_upgrade

var base_fuel: int
var base_max_speed: int
var base_torque: int
var base_dmg: int
var base_drift: float

var engine_base_lvl: int
var turbo_base_lvl: int
var shield_base_lvl: int
var carbon_base_lvl: int
var tank_base_lvl: int

var total_upgrade_cost:=0
@onready var base_available_upgrades = XPManager.available_upgrades


#GEAR PARTS
@onready var total_q: Label = $HBoxContainer/GearPanel/VBoxContainer2/TotalQ
@onready var requested_q: Label = $HBoxContainer/GearPanel/VBoxContainer2/RequestedQ
@onready var cost_q: Label = $HBoxContainer/GearPanel/VBoxContainer2/CostQ

#LEVELS
@onready var current_lvl: Label = $HBoxContainer/LvlPanel/VBoxContainer2/CurrentLvlQ
@onready var availupgrade: Label = $HBoxContainer/LvlPanel/VBoxContainer2/AvailupgradeQ

#MECHANICS LEVELS LABELS
@onready var engine_lvl: Label = $UpgradePanel/VBoxContainer/Engine/Lvl/EngineLvl
@onready var turbo_lvl: Label = $UpgradePanel/VBoxContainer/Turbo/Lvl/TurboLvl
@onready var shield_lvl: Label = $UpgradePanel/VBoxContainer/Shield/Lvl/ShieldLvl
@onready var carbon_lvl: Label = $UpgradePanel/VBoxContainer/Carbon/Lvl/CarbonLvl
@onready var tank_lvl: Label = $UpgradePanel/VBoxContainer/Tank/Lvl/TankLvl


#MECHANICS BUTTONS
@onready var engine_up: Button = $UpgradePanel/VBoxContainer/Engine/ButtonUp/EngineUp
@onready var turbo_up: Button = $UpgradePanel/VBoxContainer/Turbo/ButtonUp/TurboUp
@onready var shield_up: Button = $UpgradePanel/VBoxContainer/Shield/ButtonUp/ShieldUp
@onready var carbon_up: Button = $UpgradePanel/VBoxContainer/Carbon/ButtonUp/CarbonUp
@onready var tank_up: Button = $UpgradePanel/VBoxContainer/Tank/ButtonUp/TankUp

@onready var engine_down: Button = $UpgradePanel/VBoxContainer/Engine/ButtonDown/EngineDown
@onready var turbo_down: Button = $UpgradePanel/VBoxContainer/Turbo/ButtonDown/TurboDown
@onready var shield_down: Button = $UpgradePanel/VBoxContainer/Shield/ButtonDown/ShieldDown
@onready var carbon_down: Button = $UpgradePanel/VBoxContainer/Carbon/ButtonDown/CarbonDown
@onready var tank_down: Button = $UpgradePanel/VBoxContainer/Tank/ButtonDown/TankDown




func _ready() -> void:
	#----------TEST---------------#
	#CarManager.selected_car = CarManager.cars[0]
	#car = CarManager.selected_car
	#InventoryManager.auto_parts = 2000
	
	update_stats()
	
	base_fuel = car.max_life
	base_max_speed = car.display_max_speed
	base_torque = car.acceleration
	base_dmg = car.dmg
	base_drift = car.drift_turn_bonus + car.turn_speed
	
	engine_base_lvl = car.engine_lvl
	turbo_base_lvl = car.turbo_lvl
	shield_base_lvl = car.shield_lvl
	carbon_base_lvl = car.carbon_lvl
	
	car_name.text = car.car_name
	car_icon.texture = car.car_sprite
	
	current_lvl.text = str(XPManager.current_level)
	availupgrade.text = str(XPManager.available_upgrades)
	
	total_q.text = str(InventoryManager.auto_parts)
	requested_q.text = str(XPManager.upgrade_cost)
	base_available_upgrades = XPManager.available_upgrades
	cost_q.text = str(total_upgrade_cost)
	engine_up.grab_focus()



func _process(_delta: float) -> void:
	update_stats()
	if !upgrade_ok():
		total_q.add_theme_color_override("font_color",Color.RED)
	else : total_q.add_theme_color_override("font_color",Color.WHITE)



func update_stats():
	StatsManager.update_car_stats(car)
	
	fuel_lvl.text = str(car.max_life)
	speed_lvl.text = str(car.display_max_speed)
	torque_lvl.text = str(car.acceleration)
	dmg_lvl.text = str(car.dmg)
	drift_lvl.text = str(car.drift_turn_bonus + car.turn_speed)
	
	fuel_upgrade.text = str(car.max_life - base_fuel)
	speed_upgrade.text = str(car.display_max_speed - base_max_speed)
	torque_upgrade.text = str(car.acceleration - base_torque)
	dmg_upgrade.text = str(car.dmg - base_dmg)
	drift_upgrade.text = str(car.drift_turn_bonus + car.turn_speed - base_drift)
	
	engine_lvl.text = "Lvl " + str(car.engine_lvl)
	turbo_lvl.text = "Lvl " + str(car.turbo_lvl)
	shield_lvl.text = "Lvl " + str(car.shield_lvl)
	carbon_lvl.text = "Lvl " + str(car.carbon_lvl)
	
	availupgrade.text = str(XPManager.available_upgrades)
	requested_q.text = str(XPManager.upgrade_cost)
	cost_q.text = str(total_upgrade_cost)
	total_q.text = str(InventoryManager.auto_parts - total_upgrade_cost)
	#print(XPManager.total_upgrades)
	
	



func _on_engine_up_pressed() -> void:
	if XPManager.available_upgrades > 0 and engine_base_lvl <= car.engine_lvl and upgrade_ok():
		car.engine_lvl +=1
		#XPManager.available_upgrades -=1
		total_upgrade_cost += XPManager.cost_formula(0)
		XPManager.total_upgrades +=1
		


func _on_engine_down_pressed() -> void:
	if XPManager.available_upgrades >= 0 and engine_base_lvl < car.engine_lvl and downgrade_ok():
		car.engine_lvl -=1
		#XPManager.available_upgrades +=1
		XPManager.total_upgrades -=1
		total_upgrade_cost -= XPManager.cost_formula(0)
		

func _on_turbo_up_pressed() -> void:
	if XPManager.available_upgrades > 0 and turbo_base_lvl <= car.turbo_lvl and upgrade_ok():
		car.turbo_lvl +=1
		total_upgrade_cost += XPManager.cost_formula(0)
		XPManager.total_upgrades +=1

func _on_turbo_down_pressed() -> void:
	if XPManager.available_upgrades >= 0 and turbo_base_lvl < car.turbo_lvl and downgrade_ok():
		car.turbo_lvl -=1
		XPManager.total_upgrades -=1
		total_upgrade_cost -= XPManager.cost_formula(0)

func _on_shield_up_pressed() -> void:
	if XPManager.available_upgrades > 0 and shield_base_lvl <= car.shield_lvl and upgrade_ok():
		car.shield_lvl +=1
		total_upgrade_cost += XPManager.cost_formula(0)
		XPManager.total_upgrades +=1


func _on_shield_down_pressed() -> void:
	if XPManager.available_upgrades >= 0 and shield_base_lvl < car.shield_lvl and downgrade_ok():
		car.shield_lvl -=1
		XPManager.total_upgrades -=1
		total_upgrade_cost -= XPManager.cost_formula(0)


func _on_carbon_up_pressed() -> void:
	if XPManager.available_upgrades > 0 and carbon_base_lvl <= car.carbon_lvl and upgrade_ok():
		car.carbon_lvl +=1
		total_upgrade_cost += XPManager.cost_formula(0)
		XPManager.total_upgrades +=1


func _on_carbon_down_pressed() -> void:
	if XPManager.available_upgrades >= 0 and carbon_base_lvl < car.carbon_lvl and downgrade_ok():
		car.carbon_lvl -=1
		XPManager.total_upgrades -=1
		total_upgrade_cost -= XPManager.cost_formula(0)

func _on_tank_up_pressed() -> void:
	if XPManager.available_upgrades > 0 and tank_base_lvl <= car.tank_lvl and upgrade_ok():
		car.tank_lvl +=1
		total_upgrade_cost += XPManager.cost_formula(0)
		XPManager.total_upgrades +=1


func _on_tank_down_pressed() -> void:
	if XPManager.available_upgrades >= 0 and tank_base_lvl < car.tank_lvl and downgrade_ok():
		car.tank_lvl -=1
		XPManager.total_upgrades -=1
		total_upgrade_cost -= XPManager.cost_formula(0)

func upgrade_ok() -> bool:
	if InventoryManager.auto_parts - total_upgrade_cost >= XPManager.upgrade_cost:
		return true
	else : return false

func downgrade_ok() -> bool:
	if base_available_upgrades > XPManager.available_upgrades:
		return true
	else : return false


func _on_confirm_pressed() -> void:
	InventoryManager.auto_parts -= total_upgrade_cost
	total_upgrade_cost = 0
	base_available_upgrades = XPManager.available_upgrades
	
	base_fuel = car.max_life
	base_max_speed = car.display_max_speed
	base_torque = car.acceleration
	base_dmg = car.dmg
	base_drift = car.drift_turn_bonus + car.turn_speed
	
	engine_base_lvl = car.engine_lvl
	turbo_base_lvl = car.turbo_lvl
	shield_base_lvl = car.shield_lvl
	carbon_base_lvl = car.carbon_lvl


func _on_back_pressed() -> void:
	SceneManager.load_level(end_oy_day_scene)
