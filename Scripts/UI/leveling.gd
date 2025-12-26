extends Control

var player_current_level: int

signal game_paused(game_on_pause: bool)
var game_is_paused: = false

@onready var skip: Button = $MainButtons/Skip
@onready var confirm: Button = $MainButtons/Confirm

@onready var weapon_slot_container: GridContainer = $MarginContainer/GridContainer
var slots :int
var slot_buttons: Array

var button_base_color : Color
var button_selected_color : Color
var button_selected_id : int
var base_button_style_box : StyleBoxFlat
var selected_button_style_box : StyleBoxFlat

var weapons: Array
var weapon: WeaponData
var resource: ItemData

var unequiped_weapons :Array
var new_weapon : WeaponData

var new_weapon_show:=false

var weapon_levelup_ok:= false


func _ready() -> void:
	hide()
	WeaponsManager.new_weapon_data.connect(_update_weapons_list)
	XPManager.update_level.connect(level_up)
	
	slots = weapon_slot_container.get_child_count()
	#print(slots)
	for button in slots:
		slot_buttons.append(weapon_slot_container.get_child(button).get_child(0))
		#print(weapon_slot_container.get_child(button).get_child(0).name)
	
	for button in slot_buttons.size():
		slot_buttons[button].pressed.connect(_on_button_pressed.bind(button))

	weapons = WeaponsManager.weapons
	
	base_button_style_box = slot_buttons[0].get_theme_stylebox("normal")
	button_base_color = slot_buttons[0].get_theme_stylebox("normal").bg_color
	selected_button_style_box = StyleBoxFlat.new()
	selected_button_style_box.bg_color = Color.GOLD
	
	
func _process(_delta: float) -> void:
	pass


func level_up(new_current_level):
	player_current_level = new_current_level
	game_is_paused = true
	emit_signal("game_paused", game_is_paused)
	get_focus()
	for i in slot_buttons.size():
		if i < weapons.size():
			slot_buttons[i].get_parent().show()
		elif i == weapons.size() and new_weapon_show:
			slot_buttons[i].get_parent().show()
		else: slot_buttons[i].get_parent().hide()
	show()

func _on_skip_pressed() -> void:
	game_is_paused = false
	new_weapon_show = false
	emit_signal("game_paused", game_is_paused)
	hide()


func get_focus():
	slot_buttons[0].grab_focus()


func _on_button_pressed(button_id) -> void:
	var nb_resource_ok = 0
	
	if button_id < weapons.size():
		weapon = weapons[button_id]
	elif button_id == weapons.size():
		weapon = new_weapon
	

	for i in weapon.resources.size():
		resource = weapon.resources[i][0]
		if resource.quantity >= weapon.resources[i][1]:
			nb_resource_ok +=1
	
	if nb_resource_ok == weapon.resources.size() and weapon.current_level < weapon.max_level :
		button_selected_id = button_id
		slot_buttons[button_id].add_theme_stylebox_override("normal", selected_button_style_box)
		weapon_levelup_ok = true
		confirm.grab_focus()
		#print("level up ok for : ",weapons[button_id].weapon_name, " / id : ",button_id  )
	
	
	elif weapon.current_level >= weapon.max_level:
		slot_buttons[button_selected_id].get_child(0).add_theme_color_override("font_color", Color.RED)
		await get_tree().create_timer(0.5).timeout
		slot_buttons[button_selected_id].get_child(0).add_theme_color_override("font_color", Color.WHITE)
	else: print("skip")


func _on_confirm_pressed() -> void:
	if weapon_levelup_ok:
		slot_buttons[button_selected_id].add_theme_stylebox_override("normal", base_button_style_box) 
		game_is_paused = false
		if weapon.is_equiped:
			weapon_level_up(button_selected_id)

		else: 
			WeaponsManager.equip_weapon(weapon)
			for i in weapon.resources.size():
				resource = weapon.resources[i][0]
				resource.quantity -= weapon.resources[i][1]
		emit_signal("game_paused", game_is_paused)
		hide()
		weapon_levelup_ok = false
		new_weapon_show = false
	else: return
	

func weapon_level_up(weapon_id: int):
	weapons[weapon_id].current_level +=1
	for i in weapon.resources.size():
		resource = weapons[weapon_id].resources[i][0]
		resource.quantity -= weapon.resources[i][1]

func _update_weapons_list(new_weapon_to_equiped : WeaponData, new_weapons_list : Array, weapon_show : bool):
	new_weapon = new_weapon_to_equiped
	unequiped_weapons = new_weapons_list
	new_weapon_show = weapon_show
	#print(new_weapon.weapon_name, weapon_show)
