extends Control

var player_current_level: int

@onready var preleveling_button: Button = $MainButtons/PrelevelingButton

const UPGRADES = preload("uid://b6cie41olju8v")

func _ready() -> void:
	hide()
	XPManager.update_level.connect(level_up)
	SignalManager.upgrades_ok.connect(_on_skip_pressed)

func level_up(new_current_level : int) -> void:
	pass
	#self.show()
	#preleveling_button.grab_focus()
	#player_current_level = new_current_level
	#SignalManager.emit_signal("game_paused", true)

func _on_skip_pressed() -> void:
	SignalManager.emit_signal("game_paused", false)
	hide()

func _on_preleveling_button_pressed() -> void:
	var upgrades := UPGRADES.instantiate()
	get_parent().add_child(upgrades)
	upgrades.show()
