extends Control

var player_current_level: int

var game_is_paused: = false

const EMPTY_AMMO = preload("uid://dc7hb24vr2x6r")

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

var ammo_levelup_ok:= false
var already_selected:= false

func _ready() -> void:
	hide()
	XPManager.update_level.connect(level_up)
	
	slots = ammo_slot_container.get_child_count()
	for button_index in slots:
		confirm_buttons.append(ammo_slot_container.get_child(button_index).get_child(1))
	
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
	if visible:
		for i in ammunitions.size():
			if ammunitions[i] == EMPTY_AMMO:
				ammo_slot_container.get_child(i).get_child(0).hide()
				ammo_slot_container.get_child(i).get_child(1).hide()


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

func leveling_ok() -> void:
	for i in confirm_buttons.size():
		confirm_buttons[i].add_theme_stylebox_override("normal", base_button_style_box)
			
	if ammo_levelup_ok:
		game_is_paused = false
		if ammo.is_equiped:
			ammo.level_up()

		SignalManager.emit_signal("game_paused", game_is_paused)
		leveling.hide()
		ammo_levelup_ok = false
		#new_weapon_show = false
	else: return
