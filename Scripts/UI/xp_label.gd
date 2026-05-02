extends Label

@onready var xp_manager: Node = $"/root/XPManager"
var font_UX_XS : Array = FontManager.FONTS[FontManager.types.UX_XS]

func _ready() -> void:
	add_theme_font_override("font",font_UX_XS[0])
	add_theme_font_size_override("font_size",font_UX_XS[1])
	add_theme_color_override("font_color",font_UX_XS[2])
	
	xp_manager.update_level.connect(_update_level)
	text = "Lvl " + str(XPManager.current_level)

func _process(_delta: float) -> void:
	#text = "Lvl " + str(player_xp_manager.current_level)
	pass

func _update_level(current_level : int) -> void:
	text = "Lvl " + str(current_level)
