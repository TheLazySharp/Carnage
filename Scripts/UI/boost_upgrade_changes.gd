extends Label

var change :float
var font_text : Array = FontManager.FONTS[FontManager.types.UX_XS]

func _ready() -> void:
	add_theme_font_override("font",font_text[0])
	add_theme_font_size_override("font_size",font_text[1])
	add_theme_color_override("font_color",font_text[2])


func _process(_delta: float) -> void:
	change = float(self.text)
	if change < 0:
		self.add_theme_color_override("font_color",Color.RED)
	if change == 0:
		self.add_theme_color_override("font_color",Color.WHITE)
	if change > 0:
		self.add_theme_color_override("font_color",Color.GREEN)
