extends Label

var font_text_title : Array = FontManager.FONTS[FontManager.types.TEXT_TITLE]

func _ready() -> void:
	add_theme_font_override("font",font_text_title[0])
	add_theme_font_size_override("font_size",font_text_title[1])
	add_theme_color_override("font_color",font_text_title[2])
