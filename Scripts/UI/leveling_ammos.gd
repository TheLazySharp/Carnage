extends Control

var player_current_level: int

signal game_paused(game_on_pause: bool)
var game_is_paused: = false


@onready var ammo_slot_container: GridContainer = $GridContainer

@onready var leveling: Control = $".."


var slots : int
var confirm_buttons: Array[Button]
var ammo_data_buttons: Array[Button]


var button_base_color : Color
var button_selected_color : Color
var button_selected_id : int
var base_button_style_box : StyleBoxFlat
var selected_button_style_box : StyleBoxFlat

var ammunitions: Array[WeaponData]
var ammo: WeaponData
#var resource: ItemData

#var new_weapon : WeaponData
#
#var new_weapon_show:=false
var ammo_levelup_ok:= false
var already_selected:= false

func _ready() -> void:
	hide()
	#WeaponsManager.new_weapon_data.connect(_update_weapons_list)
	XPManager.update_level.connect(level_up)
	
	slots = ammo_slot_container.get_child_count()
	#print(slots)
	for button_index in slots:
		confirm_buttons.append(ammo_slot_container.get_child(button_index).get_child(1))
		#print("in AMMO : button name : ",ammo_slot_container.get_child(button_index).get_child(1).name)
	
	for button_index in slots:
		ammo_data_buttons.append(ammo_slot_container.get_child(button_index).get_child(0).get_child(0))
	
	for button_index in confirm_buttons.size():
		confirm_buttons[button_index].pressed.connect(_on_button_pressed.bind(button_index))

	ammunitions = WeaponsManager.ammunitions
	
	base_button_style_box = confirm_buttons[0].get_theme_stylebox("normal")
	button_base_color = confirm_buttons[0].get_theme_stylebox("normal").bg_color
	selected_button_style_box = StyleBoxFlat.new()
	selected_button_style_box.bg_color = Color.GOLD
	
	
	
func _process(_delta: float) -> void:
	pass
	#for i in ammo_data_buttons.size():
		#var button : Button = ammo_data_buttons[i]
		#if button.has_focus():
			#if i < ammunitions.size():
				#ammo_name.text = ammunitions[i].weapon_name
				#ammo_icon.texture = ammunitions[i].weapon_icon
	#if !ammunitions.is_empty():
		#for i in ammunitions.size():
			#get_child(0).get_child(i).get_child(0).get_child(2).get_child(0).texture = ammunitions[i].weapon_icon


func level_up(new_current_level : int) -> void:
	player_current_level = new_current_level
	ammunitions = WeaponsManager.ammunitions
	upgrade_ammos()
	show()


func upgrade_ammos() -> void:
	for i in confirm_buttons.size():
		if i < ammunitions.size():
			confirm_buttons[i].get_parent().show()
		else: confirm_buttons[i].get_parent().hide()



func _on_button_pressed(button_id : int) -> void:
	ammo = ammunitions[button_id]
	
	if ammo.current_level < ammo.max_level :
		button_selected_id = button_id
		for i in confirm_buttons.size():
			if i == button_id:
				confirm_buttons[button_id].add_theme_stylebox_override("normal", selected_button_style_box)
			else : confirm_buttons[i].add_theme_stylebox_override("normal", base_button_style_box)
		ammo_levelup_ok = true
		leveling_ok()
	
	
	elif ammo.current_level >= ammo.max_level:
		confirm_buttons[button_selected_id].get_child(0).add_theme_color_override("font_color", Color.RED)
		await get_tree().create_timer(0.5).timeout
		confirm_buttons[button_selected_id].get_child(0).add_theme_color_override("font_color", Color.WHITE)
	else: print("skip")


func leveling_ok() -> void:
	for i in confirm_buttons.size():
		confirm_buttons[i].add_theme_stylebox_override("normal", base_button_style_box)
			
	if ammo_levelup_ok:
		game_is_paused = false
		if ammo.is_equiped:
			ammo_level_up(button_selected_id)

		#else: 
			#WeaponsManager.equip_weapon(weapon)
		emit_signal("game_paused", game_is_paused)
		leveling.hide()
		ammo_levelup_ok = false
		#new_weapon_show = false
	else: return
	

func ammo_level_up(ammo_id: int) -> void:
	ammunitions[ammo_id].current_level +=1
	#print(weapons[weapon_id], " level up")

#func _update_weapons_list(new_weapon_to_equiped : WeaponData, new_weapons_list : Array, weapon_show : bool) -> void:
	#new_weapon = new_weapon_to_equiped
	#unequiped_weapons = new_weapons_list
	#new_weapon_show = weapon_show
	#print(new_weapon.weapon_name, weapons.size())
