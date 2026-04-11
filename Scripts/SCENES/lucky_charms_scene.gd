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

func _ready() -> void:
	#print("shuffle ok : ",LuckyCharmsManager.shuffle_lucky_charms_ok)
	max_life_on_ready = CarManager.selected_car.max_life
	print("max life : ",max_life_on_ready)
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
	if Input.is_action_just_pressed("ui_back"):
		if !LuckyCharmsManager.add_lucky_charm_ok :
			LuckyCharmsManager.call_reverse_swap()


	if new_button_group.get_pressed_button() != null :
		new_lucky_charm_index = int(new_button_group.get_pressed_button().get_parent().name)

		
		for i in current_button_group.get_buttons().size():
			current_button_group.get_buttons()[i].disabled = false


	else : 
		for i in current_button_group.get_buttons().size():
			current_button_group.get_buttons()[i].disabled = true

		
	if current_button_group.get_pressed_button() != null :
		current_lucky_charm_index = int(current_button_group.get_pressed_button().get_parent().name)
	
	if new_button_group.get_pressed_button() != null and current_button_group.get_pressed_button() != null :
		if LuckyCharmsManager.add_lucky_charm_ok :
			LuckyCharmsManager.selected_new_lucky_charms_index = new_lucky_charm_index
			LuckyCharmsManager.swap_lucky_charms(new_lucky_charm_index,current_lucky_charm_index,get_new_lucky_charms_data(new_lucky_charm_index),get_current_lucky_charms_data(current_lucky_charm_index))



func get_new_lucky_charms_data(index : int) -> LuckyCharmData:
	var selected_lucky_charm : LuckyCharmData = LuckyCharmsManager.pool[index]
	return selected_lucky_charm

func get_current_lucky_charms_data(index : int) -> LuckyCharmData:
	var selected_lucky_charm : LuckyCharmData = LuckyCharmsManager.holder[index]
	return selected_lucky_charm


func _on_confirm_pressed() -> void:
	LuckyCharmsManager.update_lucky_charms_bonus()
	SceneManager.load_level(garage_scene)
	LuckyCharmsManager.shuffle_lucky_charms_ok =  true
	LuckyCharmsManager.add_lucky_charm_ok = true
	if max_life_on_ready < CarManager.selected_car.max_life:
		StatsManager.current_life += (CarManager.selected_car.max_life -  max_life_on_ready)
		print("car max life : ",CarManager.selected_car.max_life, " / max on ready : ",max_life_on_ready)

func _on_skip_pressed() -> void:
	LuckyCharmsManager.update_lucky_charms_bonus()
	SceneManager.load_level(garage_scene)
	LuckyCharmsManager.shuffle_lucky_charms_ok =  true
	LuckyCharmsManager.add_lucky_charm_ok = true
	
