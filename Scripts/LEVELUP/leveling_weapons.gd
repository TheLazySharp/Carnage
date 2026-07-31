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
@onready var upgrades: VBoxContainer = $"../TextPanel/Upgrades"


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
var current_button : Button
var previous_button : Button


func _ready() -> void:
	hide()
	#WeaponsManager.new_weapon_data.connect(_update_weapons_list)
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
	if !visible: 
		return
	for i in weapon_data_buttons.size():
		var weapon_button : Button = weapon_data_buttons[i]
		var ammo_button : Button = ammo_data_buttons[i]
		var w_confirm_button : Button = weapon_confirm_buttons[i]
		var a_confirm_button : Button = ammo_confirm_buttons[i]
		
		#if i < weapons.size():
			#w_confirm_button.text = "UPGRADE"
		
		if weapon_button.has_focus() or w_confirm_button.has_focus() or ammo_button.has_focus() or a_confirm_button.has_focus() or skip_button.has_focus():
			if i < weapons.size():
				
				upgrades.show()
				weapon_name.text = str(WeaponsManager.Weapons_name.keys()[weapons[i].weapon_name])
				weapon_descr.text = weapons[i].description
				weapon_icon.texture = weapons[i].weapon_icon
				weapon_levels.text = str(weapons[i].current_level)
				
				if weapon_button.has_focus() or w_confirm_button.has_focus():
					SignalManager.emit_signal("selected_weapon",weapons[i],false)
					
#
				if ammo_button.has_focus() or a_confirm_button.has_focus():
					SignalManager.emit_signal("selected_weapon",weapons[i],true)
					


				if weapons[i].weapon_ammo_scene != null:
					ammo_name.show()
					ammo_name.text = str(WeaponsManager.Weapons_name.keys()[weapons[i].weapon_ammo_res.weapon_name])
					ammo_levels.show()
					ammo_levels.text = str(weapons[i].weapon_ammo_res.current_level)
					ammo_icon.get_parent().show()
					ammo_icon.texture = weapons[i].weapon_ammo_res.weapon_icon
				
				else : 
					ammo_name.hide()
					ammo_levels.hide()
					ammo_icon.get_parent().hide()
					ammo_icon.texture = null
				


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
	#elif button_id == weapons.size():
		#weapon = new_weapon
	
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
			weapon.level_up()

		SignalManager.emit_signal("game_paused", game_is_paused)
		leveling.hide()
		weapon_levelup_ok = false
		new_weapon_show = false
	else: return
	

func weapon_level_up(weapon_id: int) -> void:
	weapons[weapon_id].current_level +=1
