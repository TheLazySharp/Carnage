extends Control

@onready var resume: Button = $VBoxContainer/Resume
@onready var commands_button: Button = $VBoxContainer/Commands
@onready var quit_to_menu: Button = $"VBoxContainer/QuitToMenu"
@onready var loadout_panel: LoadoutPanel = $LoadoutPanel
@onready var maneuvers: Button = $VBoxContainer/Maneuvers
@onready var maneuvers_list: Control = $ManeuversList
@onready var pause: Control = $"."
@onready var commands_tabs: TabContainer = $Commands
@onready var gamepad_ok: Button = $"Commands/L1 <- Gamepad/Controler/VBoxContainer/GamepadOk"
@onready var keyboard_ok: Button = $"Commands/Keyboard -> R1/Keyboard/VBoxContainer/KeyboardOk"


var game_paused : bool = false

signal quit_pause(game_paused: bool)

func _ready() -> void:
	self.hide()
	commands_tabs.hide()
	resume.grab_focus()
	loadout_panel.closed.connect(get_focus)

func _process(_delta: float) -> void:
	if !commands_tabs.visible:
		return
	if Input.is_action_just_pressed("go_previous"):
		_change_tab(-1)
	elif Input.is_action_just_pressed("go_next"):
		_change_tab(1)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if !game_paused:
			game_paused = true
			SignalManager.emit_signal("game_paused", game_paused)
			if !GameMaster.tutorial_active:
				self.show()
				commands_tabs.hide()
				resume.grab_focus()

			else :
				self.hide()

		else :
			game_paused = false
			SignalManager.emit_signal("game_paused", game_paused)
			self.hide()
			commands_tabs.hide()
			loadout_panel.close()

func _on_resume_pressed() -> void:
	game_paused = false
	SignalManager.emit_signal("game_paused", game_paused)
	self.hide()
	commands_tabs.hide()
	loadout_panel.close()

func _on_commands_pressed() -> void:
	commands_tabs.show()
	BloodBars.hide()
	_focus_current_tab()

func _on_quit_to_menu_pressed() -> void:
	SceneManager.unload_game()
	SceneManager.load_level(SceneManager.SCENES.MAIN_MENU)

func get_focus() -> void:
	resume.grab_focus()


func _on_stats_pressed() -> void:
	pass # Replace with function body.


func _on_maneuvers_pressed() -> void:
	maneuvers_list.show()


func _on_loadout_pressed() -> void:
	loadout_panel.open(true)

func _on_gamepad_ok_pressed() -> void:
	_close_commands()

func _on_keyboard_ok_pressed() -> void:
	_close_commands()
	

func _change_tab(direction: int) -> void:
	commands_tabs.current_tab = wrapi(commands_tabs.current_tab + direction, 0, commands_tabs.get_tab_count())
	_focus_current_tab()

## Focus on the OK button of the visible tab: a button in a hidden tab cannot take the focus
func _focus_current_tab() -> void:
	if commands_tabs.current_tab == 0:
		gamepad_ok.grab_focus()
	else:
		keyboard_ok.grab_focus()

## Back to the pause menu, on the button that opened the commands
func _close_commands() -> void:
	commands_tabs.hide()
	commands_button.grab_focus()
	BloodBars.show()
	
