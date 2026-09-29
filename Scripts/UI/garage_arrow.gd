extends AnimatedSprite2D

var look_at_pos : Vector2

@onready var car: CharacterBody2D = $"../.."


func _ready() -> void:
	if SceneManager.race_mode:
		stop()
		hide()
		return
	SignalManager.tuto_arrow_dir.connect(update_look_at_pos)
	stop()
	hide()



func _process(_delta: float) -> void:
	if SceneManager.race_mode:
		return
	look_at(look_at_pos)

func update_look_at_pos(new_look_at_pos : Vector2) -> void:
	look_at_pos = new_look_at_pos
