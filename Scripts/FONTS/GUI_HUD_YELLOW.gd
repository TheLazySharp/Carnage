extends Label

var font_HUD_Y : Array = FontManager.FONTS[FontManager.types.UX_HUD_YELLOW]

func _ready() -> void:
	add_theme_font_override("font",font_HUD_Y[0])
	add_theme_font_size_override("font_size",font_HUD_Y[1])
	add_theme_color_override("font_color",font_HUD_Y[2])
	
	#add_theme_color_override("font_outline_color",FontManager.UX_color)
	#add_theme_constant_override("outline_size",FontManager.UX_outline)
