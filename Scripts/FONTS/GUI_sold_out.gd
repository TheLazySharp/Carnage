extends Label

var font_sold_out : Array = FontManager.FONTS[FontManager.types.SOLD_OUT]

func _ready() -> void:
	add_theme_font_override("font",font_sold_out[0])
	add_theme_font_size_override("font_size",font_sold_out[1])
	add_theme_color_override("font_color",font_sold_out[2])
	
	#add_theme_color_override("font_outline_color",FontManager.UX_color)
	#add_theme_constant_override("outline_size",FontManager.UX_outline)
