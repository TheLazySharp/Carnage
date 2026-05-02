extends Label

var font_title_low : Array = FontManager.FONTS[FontManager.types.TITLE_LOW]

func _ready() -> void:
	add_theme_font_override("font",font_title_low[0])
	add_theme_font_size_override("font_size",font_title_low[1])
	add_theme_color_override("font_color",font_title_low[2])
