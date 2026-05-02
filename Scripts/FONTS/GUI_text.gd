extends Label

var font_text : Array = FontManager.FONTS[FontManager.types.TEXT]

func _ready() -> void:
	add_theme_font_override("font",font_text[0])
	add_theme_font_size_override("font_size",font_text[1])
	add_theme_color_override("font_color",font_text[2])
