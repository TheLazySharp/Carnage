extends Control

@onready var resume: Button = $VBoxContainer/Resume
@onready var commands: Button = $VBoxContainer/Commands
@onready var quit_to_menu: Button = $"VBoxContainer/QuitToMenu"
@onready var loadout_panel: LoadoutPanel = $LoadoutPanel

var game_paused : bool = false

signal quit_pause(game_paused: bool)

func _ready() -> void:
	self.hide()
	resume.grab_focus()
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if !game_paused:
			game_paused = true
			SignalManager.emit_signal("game_paused", game_paused)
			if !GameMaster.tutorial_active:
				self.show()
				loadout_panel.open(true)
				resume.grab_focus()
				
			else : 
				self.hide()
				
		else : 
			game_paused = false
			SignalManager.emit_signal("game_paused", game_paused)
			self.hide()
			loadout_panel.close()
			
			

func _on_resume_pressed() -> void:
	game_paused = false
	SignalManager.emit_signal("game_paused", game_paused)
	self.hide()
	loadout_panel.close()

func _on_commands_pressed() -> void:
	pass

func _on_quit_to_menu_pressed() -> void:
	SceneManager.unload_game()
	SceneManager.load_level(SceneManager.SCENES.MAIN_MENU)

func get_focus() -> void:
	resume.grab_focus()


func _on_stats_pressed() -> void:
	pass # Replace with function body.
