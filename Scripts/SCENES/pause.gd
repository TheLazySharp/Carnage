extends Control

@onready var resume: Button = $VBoxContainer/Resume
@onready var commands: Button = $VBoxContainer/Commands
@onready var quit_to_menu: Button = $"VBoxContainer/QuitToMenu"

var menu_scene: String = "uid://gmjjc1vmgcds"

var game_on_pause:= false

signal quit_pause(game_on_pause: bool)

func _ready() -> void:
	resume.grab_focus()
	
func _process(_delta: float) -> void:
	pass
	#if !SceneManager.tuto_completed:
		#quit_to_menu.hide()
	#else:
		#quit_to_menu.show()
	

func _on_resume_pressed() -> void:
	game_on_pause = true
	emit_signal("quit_pause", game_on_pause)


func _on_commands_pressed() -> void:
	pass

func _on_quit_to_menu_pressed() -> void:
	SceneManager.unload_game()
	TimeManager.current_day = 0
	SceneManager.load_level(menu_scene)

func get_focus() -> void:
	resume.grab_focus()


func _on_stats_pressed() -> void:
	pass # Replace with function body.
