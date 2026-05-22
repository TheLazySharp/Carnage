extends Label

var font_vfx : Array = FontManager.FONTS[FontManager.types.VFX]

func _ready() -> void:
	add_theme_font_override("font",font_vfx[0])
	add_theme_font_size_override("font_size",font_vfx[1])
	add_theme_color_override("font_color",font_vfx[2])
