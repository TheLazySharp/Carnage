extends Button

var font_button : Array = FontManager.FONTS[FontManager.types.BUTTON]
var font_button_focus : Array = FontManager.FONTS[FontManager.types.BUTTON_FOCUS]
var font_button_pressed : Array = FontManager.FONTS[FontManager.types.BUTTON_PRESSED]
var font_button_hover : Array = FontManager.FONTS[FontManager.types.BUTTON_HOVER]

func _ready() -> void:
	add_theme_font_override("font",font_button[0])
	add_theme_font_size_override("font_size",font_button[1])
	add_theme_color_override("font_color",font_button[2])
	add_theme_color_override("font_focus_color",font_button_focus[2])
	add_theme_color_override("font_pressed_color",font_button_pressed[2])
	add_theme_color_override("font_hover_color",font_button_hover[2])
	
	var new_stylebox : StyleBox = get_theme_stylebox("focus")
	new_stylebox.border_color = FontManager.dark_yellow
	add_theme_stylebox_override("focus",new_stylebox)
