extends AnimatedSprite2D

var look_at_pos : Vector2

@onready var car: CharacterBody2D = $"../.."


func _ready() -> void:
	SignalManager.tuto_arrow_dir.connect(update_look_at_pos)
	stop()
	hide()



func _process(_delta: float) -> void:
	look_at(look_at_pos)

func update_look_at_pos(new_look_at_pos : Vector2) -> void:
	look_at_pos = new_look_at_pos
