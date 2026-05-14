extends Button

var font_menu : Array = FontManager.FONTS[FontManager.types.MENU]
var font_menu_focus : Array = FontManager.FONTS[FontManager.types.MENU_FOCUS]
var font_menu_pressed : Array = FontManager.FONTS[FontManager.types.MENU_PRESSED]
var font_menu_hover : Array = FontManager.FONTS[FontManager.types.MENU_HOVER]

func _ready() -> void:
	add_theme_font_override("font",font_menu[0])
	add_theme_font_size_override("font_size",font_menu[1])
	add_theme_color_override("font_color",font_menu[2])
	add_theme_color_override("font_focus_color",font_menu_focus[2])
	add_theme_color_override("font_pressed_color",font_menu_pressed[2])
	add_theme_color_override("font_hover_color",font_menu_hover[2])
	add_theme_constant_override("h_separation",FontManager.button_H_sep)
	alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT



func _process(_delta: float) -> void:
	if self.has_focus():
		icon = FontManager.BUTTON_ICON
	else : 
		icon = null
