extends Node2D

@onready var sub_viewport: SubViewport = $SubViewport
@onready var display: Sprite2D = $Display

func _ready() -> void:
	display.texture = sub_viewport.get_texture()
	display.centered = false   # pour que la texture s'aligne pile sur (0,0) du SubViewport
