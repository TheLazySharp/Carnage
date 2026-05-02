extends Label

var font_UX : Array = FontManager.FONTS[FontManager.types.UX]

func _process(_delta: float) -> void:
	set_text("FPS " + str(Engine.get_frames_per_second()))


func _ready() -> void:
	add_theme_font_override("font",font_UX[0])
	add_theme_font_size_override("font_size",font_UX[1])
	add_theme_color_override("font_color",font_UX[2])
	
	add_theme_color_override("font_outline_color",FontManager.UX_color)
	add_theme_constant_override("outline_size",FontManager.UX_outline)
