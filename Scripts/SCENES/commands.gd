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


func _on_back_pressed() -> void:
	controler.hide()
	keyboard.show()
	ok_keyboard.grab_focus()


func _on_ok_keyboard_pressed() -> void:
	SceneManager.load_level(SceneManager.SCENES.MISSIONS)
