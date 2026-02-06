extends AnimatedSprite2D

var look_at_pos : Vector2

@onready var car: CharacterBody2D = $"../.."


func _ready() -> void:
	stop()
	hide()
	look_at_pos = car.global_position


func _process(_delta: float) -> void:
	look_at(look_at_pos)
