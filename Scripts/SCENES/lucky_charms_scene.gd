extends Control

@onready var new_button0: Button = $NewLuckyCharms/HBoxContainer/Charm0/Button
@export var new_button_group : ButtonGroup
@export var current_button_group : ButtonGroup
@onready var confirm: Button = $VBoxContainer/Confirm
@onready var skip: Button = $VBoxContainer/Skip
var max_life_on_ready : int

var new_lucky_charm_index : int = 0
var current_lucky_charm_index : int = 0

var garage_scene := "uid://cs311xlcqlrt0"
var current_scene:= "uid://ch2rp03kbdyg7"
var end_of_day_scene : String = "uid://dkpvtoel7hhai"

var player : CarData
var target_weapon : WeaponData
var target_stat : Statistic


func _ready() -> void:
	new_button_group.pressed.connect(_on_new_charm_selected)
	current_button_group.pressed.connect(_on_current_charm_selected)
	max_life_on_ready = int(CarManager.selected_car.max_life.get_value())

	if LuckyCharmsManager.shuffle_lucky_charms_ok :
		LuckyCharmsManager.shuffle()
		LuckyCharmsManager.shuffle_lucky_charms_ok =  false
	new_button0.grab_focus()
	
	for i in current_button_group.get_buttons().size():
		current_button_group.get_buttons()[i].disabled = true

	if LuckyCharmsManager.add_lucky_charm_ok:
		confirm.text = ""
		skip.show()
		
	else :
		confirm.text = "CONFIRM"
		confirm.grab_focus()
		skip.hide()

func _process(_delta: float) -> void:
	pass


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_back"):
		if !LuckyCharmsManager.add_lucky_charm_ok :
			LuckyCharmsManager.call_reverse_swap()

func get_new_lucky_charms_data(index : int) -> CharmData:
	return LuckyCharmsManager.shuffled_pool_copy[index]

func get_current_lucky_charms_data(index : int) -> CharmData:
	var selected_lucky_charm : CharmData = LuckyCharmsManager.holder[index]
	return selected_lucky_charm


func _on_confirm_pressed() -> void:
	LuckyCharmsManager.apply_charm_modifier(LuckyCharmsManager.last_added_lucky_charm)
	LuckyCharmsManager.shuffle_lucky_charms_ok =  true
	LuckyCharmsManager.add_lucky_charm_ok = true
	if max_life_on_ready < CarManager.selected_car.max_life.get_value():
		player.current_life += roundi((CarManager.selected_car.max_life.get_value() -  max_life_on_ready))
	SceneManager.load_level(garage_scene)

func _on_skip_pressed() -> void:
	SceneManager.load_level(garage_scene)
	LuckyCharmsManager.shuffle_lucky_charms_ok =  true
	LuckyCharmsManager.add_lucky_charm_ok = true

func _on_new_charm_selected(_button : BaseButton) -> void : 
	new_lucky_charm_index = int(new_button_group.get_pressed_button().get_parent().name)

	for i in new_button_group.get_buttons().size():
		new_button_group.get_buttons()[i].disabled = true
	
	for i in current_button_group.get_buttons().size():
		current_button_group.get_buttons()[i].disabled = false
	
	current_button_group.get_buttons()[0].grab_focus()

func _on_current_charm_selected(_button : BaseButton) -> void : 
	current_lucky_charm_index = int(current_button_group.get_pressed_button().get_parent().name)
		
	if new_button_group.get_pressed_button() == null:
		return
	
	if LuckyCharmsManager.add_lucky_charm_ok :
		LuckyCharmsManager.selected_new_lucky_charms_index = new_lucky_charm_index
		LuckyCharmsManager.last_added_lucky_charm = get_new_lucky_charms_data(new_lucky_charm_index)
		LuckyCharmsManager.swap_lucky_charms(new_lucky_charm_index,current_lucky_charm_index,get_new_lucky_charms_data(new_lucky_charm_index),get_current_lucky_charms_data(current_lucky_charm_index))
