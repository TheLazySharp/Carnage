extends Control

var player_current_level: int

var game_is_paused: = false

@onready var prelevelling: Control = $"../Prelevelling"
@onready var preleveling_button: Button = $"../Prelevelling/MainButtons/PrelevelingButton"
@onready var weapon_slot_container: GridContainer = $WeaponsContainer/GridContainer
@onready var weapon_button0: Button = $WeaponsContainer/GridContainer/WeaponSlot0/Weapon/Button


func _ready() -> void:
	hide()
	prelevelling.hide()
	XPManager.update_level.connect(level_up)

	

func level_up(new_current_level : int) -> void:
	prelevelling.show()
	preleveling_button.grab_focus()
	player_current_level = new_current_level
	game_is_paused = true
	SignalManager.emit_signal("game_paused", game_is_paused)


func _on_skip_pressed() -> void:
	game_is_paused = false
	SignalManager.emit_signal("game_paused", game_is_paused)
	hide()


func _on_preleveling_button_pressed() -> void:
	prelevelling.hide()
	self.show()
	weapon_button0.grab_focus()
