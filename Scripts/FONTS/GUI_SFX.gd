extends Label

var font_sfx : Array = FontManager.FONTS[FontManager.types.SFX]

func _ready() -> void:
	add_theme_font_override("font",font_sfx[0])
	add_theme_font_size_override("font_size",font_sfx[1])
	add_theme_color_override("font_color",font_sfx[2])
