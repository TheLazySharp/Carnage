extends Control

@onready var controler: Control = $Controler
@onready var ok_controler: Button = $Controler/VBoxContainer/Ok

@onready var keyboard: Control = $Keyboard
@onready var ok_keyboard: Button = $Keyboard/VBoxContainer/Ok


func _ready() -> void:
	ok_controler.grab_focus() 
	keyboard.hide()
	controler.show()


func _process(_delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_back"):
		SceneManager.load_level(SceneManager.SCENES.MAIN_MENU)
		

func _on_back_pressed() -> void:
	controler.hide()
	keyboard.show()
	ok_keyboard.grab_focus()


func _on_ok_keyboard_pressed() -> void:
	if SceneManager.commands_from_menu : 
		SceneManager.load_level(SceneManager.SCENES.MAIN_MENU)
		SceneManager.commands_from_menu = false
	else :
		SceneManager.load_level(SceneManager.SCENES.MISSIONS)
