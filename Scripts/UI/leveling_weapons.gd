extends Control

var player_current_level: int

var game_is_paused: = false


@onready var weapon_slot_container: GridContainer = $GridContainer
@onready var ammo_slot_container: GridContainer = $"../AmmoContainer/GridContainer"

@onready var leveling: Control = $".."
@onready var skip_button: Button = $"../LevelingBkgd/MainButtons/Skip"


#TEXT
@onready var weapon_name: Label = $"../TextPanel/WeaponName"
@onready var weapon_descr: Label = $"../TextPanel/WeaponDescr"
@onready var weapon_icon: TextureRect = $"../TextPanel/WeaponBkg/WeaponIcon"
@onready var weapon_levels: Label = $"../TextPanel/WeaponLevels"
@onready var ammo_name: Label = $"../TextPanel/AmmoName"
@onready var ammo_levels: Label = $"../TextPanel/AmmoLevels"
@onready var ammo_icon: TextureRect = $"../TextPanel/AmmoBkg/AmmoIcon"
@onready var ammo_bkg: ColorRect = $"../TextPanel/AmmoBkg"

#STATS
@onready var upgrades: HBoxContainer = $"../TextPanel/Upgrades"
@onready var dmg_current: Label = $"../TextPanel/Upgrades/Levels/Dmg_Q"
@onready var dmg_upgrade: Label = $"../TextPanel/Upgrades/Upgrade/Dmg_upgrade"

@onready var fire_rate_current: Label = $"../TextPanel/Upgrades/Levels/FireRate_Q"
@onready var fire_rate_upgrade: Label = $"../TextPanel/Upgrades/Upgrade/FireRate_upgrade"

@onready var cool_down_current: Label = $"../TextPanel/Upgrades/Levels/CoolDown_Q"
@onready var cool_down_upgrade: Label = $"../TextPanel/Upgrades/Upgrade/CoolDown_upgrade"

@onready var radius_current: Label = $"../TextPanel/Upgrades/Levels/Radius_Q"
@onready var radius_upgrade: Label = $"../TextPanel/Upgrades/Upgrade/Radius_upgrade"

@onready var nb_ammo_current: Label = $"../TextPanel/Upgrades/Levels/NbAmmo_Q"
@onready var nb_ammo_upgrade: Label = $"../TextPanel/Upgrades/Upgrade/NbAmmo_upgrade"


var slots :int
var weapon_confirm_buttons: Array[Button]
var weapon_data_buttons: Array[Button]
var ammo_data_buttons: Array[Button]
var ammo_confirm_buttons: Array[Button]


var button_base_color : Color
var button_selected_color : Color
var button_selected_id : int
var base_button_style_box : StyleBoxFlat
var selected_button_style_box : StyleBoxFlat

var weapons: Array[WeaponData]
var ammunitions: Array[WeaponData]
var weapon: WeaponData
var resource: ItemData

var unequiped_weapons :Array
var new_weapon : WeaponData

var new_weapon_show:=false
var weapon_levelup_ok:= false
var already_selected:= false

func _ready() -> void:
	hide()
	WeaponsManager.new_weapon_data.connect(_update_weapons_list)
	XPManager.update_level.connect(level_up)
	
	slots = weapon_slot_container.get_child_count()
	
	for button_index in slots:
		weapon_confirm_buttons.append(weapon_slot_container.get_child(button_index).get_child(1))
		ammo_confirm_buttons.append(ammo_slot_container.get_child(button_index).get_child(1))
	
	for button_index in slots:
		weapon_data_buttons.append(weapon_slot_container.get_child(button_index).get_child(0).get_child(0))
		ammo_data_buttons.append(ammo_slot_container.get_child(button_index).get_child(0).get_child(0))
	
	
	for button_index in weapon_confirm_buttons.size():
		weapon_confirm_buttons[button_index].pressed.connect(_on_button_pressed.bind(button_index))

	weapons = WeaponsManager.weapons
	ammunitions = WeaponsManager.ammunitions
	
	base_button_style_box = weapon_confirm_buttons[0].get_theme_stylebox("normal")
	button_base_color = weapon_confirm_buttons[0].get_theme_stylebox("normal").bg_color
	selected_button_style_box = StyleBoxFlat.new()
	selected_button_style_box.bg_color = Color.GOLD
	
	
	
func _process(_delta: float) -> void:
	if visible: 
		for i in weapon_data_buttons.size():
			var weapon_button : Button = weapon_data_buttons[i]
			var ammo_button : Button = ammo_data_buttons[i]
			var w_confirm_button : Button = weapon_confirm_buttons[i]
			var a_confirm_button : Button = ammo_confirm_buttons[i]
			
			if i < weapons.size():
				w_confirm_button.text = "UPGRADE"
			elif i == weapons.size():
				w_confirm_button.text = "EQUIP"
			
			if weapon_button.has_focus() or w_confirm_button.has_focus() or ammo_button.has_focus() or a_confirm_button.has_focus() or skip_button.has_focus():
				if i < weapons.size():
					upgrades.show()
					weapon_name.text = weapons[i].weapon_name
					weapon_descr.text = weapons[i].description
					weapon_icon.texture = weapons[i].weapon_icon
					weapon_levels.text = str(weapons[i].current_level)
					

					
					#STATS
					
					if ammo_button.has_focus() or a_confirm_button.has_focus():
						dmg_current.text = str(weapons[i].dmg + weapons[i].weapon_ammo_res.dmg)
						dmg_upgrade.text = str(weapons[i].dmg_upgrade + weapons[i].weapon_ammo_res.dmg_upgrade)
						if int(dmg_upgrade.text) > int(dmg_current.text):
							dmg_upgrade.add_theme_color_override("font_color",Color.GREEN)
						else :
							dmg_upgrade.add_theme_color_override("font_color",Color.WHITE)
						
						fire_rate_current.text = str(weapons[i].fire_rate)
						fire_rate_upgrade.text = fire_rate_current.text
						if float(fire_rate_upgrade.text) < float(fire_rate_current.text):
							fire_rate_upgrade.add_theme_color_override("font_color",Color.GREEN)
						else :
							fire_rate_upgrade.add_theme_color_override("font_color",Color.WHITE)
						
						cool_down_current.text = str(weapons[i].cool_down)
						cool_down_upgrade.text = cool_down_current.text
						if float(cool_down_upgrade.text) < float(cool_down_current.text):
							cool_down_upgrade.add_theme_color_override("font_color",Color.GREEN)
						else :
							cool_down_upgrade.add_theme_color_override("font_color",Color.WHITE)
						
						radius_current.text = str(weapons[i].radius)
						radius_upgrade.text = radius_current.text
						if float(radius_upgrade.text) > float(radius_current.text):
							radius_upgrade.add_theme_color_override("font_color",Color.GREEN)
						else :
							radius_upgrade.add_theme_color_override("font_color",Color.WHITE)
						
						nb_ammo_current.text = str(weapons[i].nb_ammo)
						nb_ammo_upgrade.text = nb_ammo_current.text
						if int(nb_ammo_upgrade.text) > int(nb_ammo_current.text):
							nb_ammo_upgrade.add_theme_color_override("font_color",Color.GREEN)
						else :
							nb_ammo_upgrade.add_theme_color_override("font_color",Color.WHITE)
					
					if weapon_button.has_focus() or w_confirm_button.has_focus():
						if weapons[i].weapon_ammo_scene == null:
							dmg_current.text = str(weapons[i].dmg + weapons[i].weapon_ammo_res.dmg)
							dmg_upgrade.text = str(weapons[i].dmg_upgrade + weapons[i].weapon_ammo_res.dmg_upgrade)
							
							if int(dmg_upgrade.text) > int(dmg_current.text):
								dmg_upgrade.add_theme_color_override("font_color",Color.GREEN)
							else :
								dmg_upgrade.add_theme_color_override("font_color",Color.WHITE)
							
							ammo_icon.get_parent().hide()
							ammo_name.hide()
							ammo_levels.hide()
							
						else:
							dmg_current.text = str(weapons[i].dmg + weapons[i].weapon_ammo_res.dmg)
							dmg_upgrade.text = dmg_current.text
							
							if int(dmg_upgrade.text) > int(dmg_current.text):
								dmg_upgrade.add_theme_color_override("font_color",Color.GREEN)
							else :
								dmg_upgrade.add_theme_color_override("font_color",Color.WHITE)
							
							ammo_icon.get_parent().show()
							ammo_name.show()
							ammo_levels.show()
						
						
						fire_rate_current.text = str(weapons[i].fire_rate)
						fire_rate_upgrade.text = str(weapons[i].fire_rate_upgrade)
						if float(fire_rate_upgrade.text) < float(fire_rate_current.text):
							fire_rate_upgrade.add_theme_color_override("font_color",Color.GREEN)
						else :
							fire_rate_upgrade.add_theme_color_override("font_color",Color.WHITE)
							
						cool_down_current.text = str(weapons[i].cool_down)
						cool_down_upgrade.text = str(weapons[i].cool_down_upgrade)
						if float(cool_down_upgrade.text) < float(cool_down_current.text):
							cool_down_upgrade.add_theme_color_override("font_color",Color.GREEN)
						else :
							cool_down_upgrade.add_theme_color_override("font_color",Color.WHITE)
						
						radius_current.text = str(weapons[i].radius)
						radius_upgrade.text = str(weapons[i].radius_upgrade)
						if float(radius_upgrade.text) > float(radius_current.text):
							radius_upgrade.add_theme_color_override("font_color",Color.GREEN)
						else :
							radius_upgrade.add_theme_color_override("font_color",Color.WHITE)
						
						nb_ammo_current.text = str(weapons[i].nb_ammo)
						nb_ammo_upgrade.text = str(weapons[i].nb_ammo_upgrade)
						if int(nb_ammo_upgrade.text) > int(nb_ammo_current.text):
							nb_ammo_upgrade.add_theme_color_override("font_color",Color.GREEN)
						else :
							nb_ammo_upgrade.add_theme_color_override("font_color",Color.WHITE)
							
					if weapons[i].weapon_ammo_scene != null:
						ammo_name.show()
						ammo_name.text = weapons[i].weapon_ammo_res.weapon_name
						ammo_levels.show()
						ammo_levels.text = str(weapons[i].weapon_ammo_res.current_level)
						ammo_icon.get_parent().show()
						ammo_icon.texture = weapons[i].weapon_ammo_res.weapon_icon
					
				elif i == weapons.size() and !unequiped_weapons.is_empty() : #NEW WEAPON TO EQUIP
					upgrades.hide()
					weapon_name.text = new_weapon.weapon_name
					weapon_descr.text = new_weapon.description
					weapon_icon.texture = new_weapon.weapon_icon
					weapon_levels.text = "100"
					ammo_name.hide()
					ammo_levels.hide()
					ammo_icon.get_parent().hide()
	



func level_up(new_current_level : int) -> void:
	player_current_level = new_current_level
	ammunitions = WeaponsManager.ammunitions
	for i in ammunitions.size():
		ammo_slot_container.get_child(i).get_child(0).get_child(2).get_child(0).texture = ammunitions[i].weapon_icon
	upgrade_weapons()



func upgrade_weapons() -> void:
	get_focus()
	for i in weapon_confirm_buttons.size():
		if i < weapons.size():
			weapon_confirm_buttons[i].get_parent().show()
		elif i == weapons.size() and new_weapon_show:
			weapon_confirm_buttons[i].get_parent().show()
		else: weapon_confirm_buttons[i].get_parent().hide()
	show()


func get_focus() -> void:
	weapon_data_buttons[0].grab_focus()

func _on_button_pressed(button_id : int) -> void:

	if button_id < weapons.size():
		weapon = weapons[button_id]
	elif button_id == weapons.size():
		weapon = new_weapon
	
	if weapon.current_level < weapon.max_level :
		button_selected_id = button_id
		for i in weapon_confirm_buttons.size():
			if i == button_id:
				weapon_confirm_buttons[button_id].add_theme_stylebox_override("normal", selected_button_style_box)
			else : weapon_confirm_buttons[i].add_theme_stylebox_override("normal", base_button_style_box)
		weapon_levelup_ok = true
		leveling_ok()
	
	
	elif weapon.current_level >= weapon.max_level:
		weapon_confirm_buttons[button_selected_id].get_child(0).add_theme_color_override("font_color", Color.RED)
		await get_tree().create_timer(0.5).timeout
		weapon_confirm_buttons[button_selected_id].get_child(0).add_theme_color_override("font_color", Color.WHITE)
	#else: print("skip")


func leveling_ok() -> void:
	for i in weapon_confirm_buttons.size():
		weapon_confirm_buttons[i].add_theme_stylebox_override("normal", base_button_style_box)
			
	if weapon_levelup_ok:
		game_is_paused = false
		if weapon.is_equiped:
			weapon_level_up(button_selected_id)

		else: 
			WeaponsManager.equip_weapon(weapon)
		SignalManager.emit_signal("game_paused", game_is_paused)
		leveling.hide()
		weapon_levelup_ok = false
		new_weapon_show = false
	else: return
	

func weapon_level_up(weapon_id: int) -> void:
	weapons[weapon_id].current_level +=1
	StatsManager.update_car_stats(CarManager.selected_car)

	#print(weapons[weapon_id], " level up")

func _update_weapons_list(new_weapon_to_equiped : WeaponData, new_weapons_list : Array, weapon_show : bool) -> void:
	new_weapon = new_weapon_to_equiped
	unequiped_weapons = new_weapons_list
	new_weapon_show = weapon_show
