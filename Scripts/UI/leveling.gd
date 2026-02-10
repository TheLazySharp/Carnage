extends Control

var player_current_level: int

signal game_paused(game_on_pause: bool)
var game_is_paused: = false

@onready var prelevelling: Control = $"../Prelevelling"


@onready var preleveling_button: Button = $"../Prelevelling/MainButtons/PrelevelingButton"

@onready var weapon_slot_container: GridContainer = $WeaponsContainer/GridContainer

@onready var weapon_button0: Button = $WeaponsContainer/GridContainer/WeaponSlot0/Weapon/Button


#
#var slots :int
#var slot_buttons: Array
#
#var button_base_color : Color
#var button_selected_color : Color
#var button_selected_id : int
#var base_button_style_box : StyleBoxFlat
#var selected_button_style_box : StyleBoxFlat

#var weapons: Array
#var weapon: WeaponData
#var resource: ItemData

#var unequiped_weapons :Array
#var new_weapon : WeaponData

#var new_weapon_show:=false
#var weapon_levelup_ok:= false
#var already_selected:= false

func _ready() -> void:
	hide()
	prelevelling.hide()
	#WeaponsManager.new_weapon_data.connect(_update_weapons_list)
	XPManager.update_level.connect(level_up)
	
	#slots = weapon_slot_container.get_child_count()
	##print(slots)
	#for button in slots:
		#slot_buttons.append(weapon_slot_container.get_child(button).get_child(0))
		##print(weapon_slot_container.get_child(button).get_child(0).name)
	
	#for button in slot_buttons.size():
		#slot_buttons[button].pressed.connect(_on_button_pressed.bind(button))

	#weapons = WeaponsManager.weapons
	
	#base_button_style_box = slot_buttons[0].get_theme_stylebox("normal")
	#button_base_color = slot_buttons[0].get_theme_stylebox("normal").bg_color
	#selected_button_style_box = StyleBoxFlat.new()
	#selected_button_style_box.bg_color = Color.GOLD
	
	

func level_up(new_current_level : int) -> void:
	prelevelling.show()
	preleveling_button.grab_focus()
	player_current_level = new_current_level
	game_is_paused = true
	emit_signal("game_paused", game_is_paused)

#
#
#func upgrade_weapons() -> void:
	#get_focus()
	#for i in slot_buttons.size():
		#if i < weapons.size():
			#slot_buttons[i].get_parent().show()
		#elif i == weapons.size() and new_weapon_show:
			#slot_buttons[i].get_parent().show()
		#else: slot_buttons[i].get_parent().hide()
	#show()



func _on_skip_pressed() -> void:
	#for i in slot_buttons.size():
		#slot_buttons[i].add_theme_stylebox_override("normal", base_button_style_box)
	game_is_paused = false
	#new_weapon_show = false
	emit_signal("game_paused", game_is_paused)
	hide()


#func get_focus() -> void:
	#slot_buttons[0].grab_focus()


#func _on_button_pressed(button_id : int) -> void:
#
	#if button_id < weapons.size():
		#weapon = weapons[button_id]
	#elif button_id == weapons.size():
		#weapon = new_weapon
	#
	#if weapon.current_level < weapon.max_level :
		#button_selected_id = button_id
		#for i in slot_buttons.size():
			#print(i," / ",button_id)
			#if i == button_id:
				#slot_buttons[button_id].add_theme_stylebox_override("normal", selected_button_style_box)
			#else : slot_buttons[i].add_theme_stylebox_override("normal", base_button_style_box)
		#weapon_levelup_ok = true
		#confirm.grab_focus()
		##print("level up ok for : ",weapons[button_id].weapon_name, " / id : ",button_id  )
	#
	#
	#elif weapon.current_level >= weapon.max_level:
		#slot_buttons[button_selected_id].get_child(0).add_theme_color_override("font_color", Color.RED)
		#await get_tree().create_timer(0.5).timeout
		#slot_buttons[button_selected_id].get_child(0).add_theme_color_override("font_color", Color.WHITE)
	#else: print("skip")


#func _on_confirm_pressed() -> void:
	#for i in slot_buttons.size():
		#slot_buttons[i].add_theme_stylebox_override("normal", base_button_style_box)
			#
	#if weapon_levelup_ok:
		#game_is_paused = false
		#if weapon.is_equiped:
			#weapon_level_up(button_selected_id)
#
		#else: 
			#WeaponsManager.equip_weapon(weapon)
		#emit_signal("game_paused", game_is_paused)
		#hide()
		#weapon_levelup_ok = false
		#new_weapon_show = false
	#else: return
	

#func weapon_level_up(weapon_id: int) -> void:
	#weapons[weapon_id].current_level +=1

#func _update_weapons_list(new_weapon_to_equiped : WeaponData, new_weapons_list : Array, weapon_show : bool) -> void:
	#new_weapon = new_weapon_to_equiped
	#unequiped_weapons = new_weapons_list
	#new_weapon_show = weapon_show
	##print(new_weapon.weapon_name, weapon_show)


func _on_preleveling_button_pressed() -> void:
	print("ok pressed")
	prelevelling.hide()
	self.show()
	weapon_button0.grab_focus()

	#upgrade_weapons()
