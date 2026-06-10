extends Control

@onready var ok: Button = $VBoxContainer/Ok


func _ready() -> void:
	ok.grab_focus()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_back"):
		SceneManager.load_level(SceneManager.SCENES.COMMANDS)


func _on_back_pressed() -> void:
	if !SceneManager.commands_displayed:
		SceneManager.load_level(SceneManager.SCENES.SURVIVORS)
		SceneManager.commands_displayed = true
		return
	SceneManager.commands_displayed = true
	SceneManager.load_level(SceneManager.SCENES.MAIN_MENU)
