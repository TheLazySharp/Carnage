extends HBoxContainer

var weapon : WeaponData
var ammo : WeaponData
var weapon_stat : Statistic
var ammo_stat : Statistic
var weapon_target_stat : Statistic
var ammo_target_stat : Statistic
@export var UI_stat_type : WeaponData.Stats_Types

#@onready var stat_name: Label = $StatName
@onready var stat_base_value: Label = $StatBaseValue
@onready var stat_upgrade_value: Label = $StatUpgradeValue
@onready var upgrades: VBoxContainer = $".."
var ressource_is_ammo : bool = false

func _ready() -> void:
	SignalManager.selected_weapon.connect(_on_weapon_selected)
	SignalManager.emit_signal("selected_weapon",WeaponsManager.weapons[0],false)

	weapon_stat = weapon.stats[UI_stat_type]
	weapon_target_stat = weapon.get_target_upgrade_stat()
	
	if !weapon.weapon_ammo_res and !ressource_is_ammo:
		stat_base_value.text = str(weapon_stat.get_value())
		if weapon_target_stat == weapon_stat :
			stat_upgrade_value.text = str(weapon.get_target_stat_new_value(1))
		else : 
			stat_upgrade_value.text = str(weapon_stat.get_value())

	else:
		ammo = weapon.weapon_ammo_res
		ammo_stat = ammo.stats[UI_stat_type]
		ammo_target_stat = ammo.get_target_upgrade_stat()
		
		stat_base_value.text = str(weapon_stat.get_value() + ammo_stat.get_value())
		
		if ressource_is_ammo :
			if ammo_target_stat == ammo_stat:
				stat_upgrade_value.text = str(weapon_stat.get_value() + ammo.get_target_stat_new_value(1))			
			else :
				stat_upgrade_value.text = str(weapon_stat.get_value() + ammo_stat.get_value())
		
		else : 
			if weapon_target_stat == weapon_stat:
				stat_upgrade_value.text = str(weapon.get_target_stat_new_value(1) + ammo_stat.get_value())			
			else :
				stat_upgrade_value.text = str(weapon_stat.get_value() + ammo_stat.get_value())


func _process(_delta: float) -> void:
	if upgrades.visible:
		self.show()
	if !visible:
		return
		
	weapon_stat = weapon.stats[UI_stat_type]
	weapon_target_stat = weapon.get_target_upgrade_stat()
	ammo = weapon.weapon_ammo_res
	ammo_stat = ammo.stats[UI_stat_type]
	ammo_target_stat = ammo.get_target_upgrade_stat()
	
	if !weapon.weapon_ammo_res and !ressource_is_ammo:
		stat_base_value.text = str(weapon_stat.get_value())
		if weapon_target_stat == weapon_stat :
			stat_upgrade_value.text = str(weapon.get_target_stat_new_value(1))
		else : 
			stat_upgrade_value.text = str(weapon_stat.get_value())

	else:
		stat_base_value.text = str(weapon_stat.get_value() + ammo_stat.get_value())
		
		if ressource_is_ammo :
			if ammo_target_stat == ammo_stat:
				stat_upgrade_value.text = str(weapon_stat.get_value() + ammo.get_target_stat_new_value(1))
			else :
				stat_upgrade_value.text = str(weapon_stat.get_value() + ammo_stat.get_value())
		
		else : 
			if weapon_target_stat == weapon_stat:
				stat_upgrade_value.text = str(weapon.get_target_stat_new_value(1) + ammo_stat.get_value())
			else :
				stat_upgrade_value.text = str(weapon_stat.get_value() + ammo_stat.get_value())
		
	
	if UI_stat_type == WeaponData.Stats_Types.DMG or UI_stat_type == WeaponData.Stats_Types.NB_AMMO or UI_stat_type == WeaponData.Stats_Types.RANGE or UI_stat_type == WeaponData.Stats_Types.RADIUS:
		if float(stat_base_value.text) < float(stat_upgrade_value.text):
			stat_upgrade_value.add_theme_color_override("font_color",Color.GREEN)
		else :
			stat_upgrade_value.add_theme_color_override("font_color",Color.WHITE)
	else :
		if float(stat_base_value.text) > float(stat_upgrade_value.text):
			stat_upgrade_value.add_theme_color_override("font_color",Color.GREEN)
		else :
			stat_upgrade_value.add_theme_color_override("font_color",Color.WHITE)

func _on_weapon_selected(p_weapon : WeaponData, p_is_ammo : bool) -> void : 
	weapon = p_weapon
	ressource_is_ammo = p_is_ammo
