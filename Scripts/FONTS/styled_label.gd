class_name StyledLabel
extends Label

var font_text : Array = FontManager.FONTS[FontManager.types.UX_XS]


func _ready() -> void:
	add_theme_font_override("font", font_text[0])
	add_theme_font_size_override("font_size", font_text[1])
	# Never stomp a color an owner script may already have applied
	if not has_theme_color_override("font_color"):
		add_theme_color_override("font_color", font_text[2])


## Owner-driven color
func set_color(color : Color) -> void:
	add_theme_color_override("font_color", color)


## Back to the FontManager default color
func reset_color() -> void:
	add_theme_color_override("font_color", font_text[2])
