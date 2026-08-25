extends Label

var font_UX : Array = FontManager.FONTS[FontManager.types.UX]

func _ready() -> void:
	if GameMaster.game_mode ==  GameMaster.GAME_MODES.BUILD or GameMaster.game_mode ==  GameMaster.GAME_MODES.RELEASE:
		hide()
		return
		
	add_theme_font_override("font",font_UX[0])
	add_theme_font_size_override("font_size",font_UX[1])
	add_theme_color_override("font_color",font_UX[2])
	
	add_theme_color_override("font_outline_color",FontManager.dark_yellow)
	add_theme_constant_override("outline_size",FontManager.UX_outline)


func _process(_delta: float) -> void:
	if GameMaster.game_mode ==  GameMaster.GAME_MODES.BUILD or GameMaster.game_mode ==  GameMaster.GAME_MODES.RELEASE:
		pass
	set_text("FPS " + str(Engine.get_frames_per_second()))
