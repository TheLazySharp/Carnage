extends Label

var change :int

func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	change = int(self.text)
	if change < 0:
		self.add_theme_color_override("font_color",Color.RED)
	if change == 0:
		self.add_theme_color_override("font_color",Color.WHITE)
	if change > 0:
		self.add_theme_color_override("font_color",Color.GREEN)
		
