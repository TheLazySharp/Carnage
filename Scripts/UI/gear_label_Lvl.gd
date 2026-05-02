extends Label

var weapon_list: Array
var weapon: WeaponData

var panel_name:=""
var i: int

var font_UX_XS : Array = FontManager.FONTS[FontManager.types.UX_XS]


func _ready() -> void:
	add_theme_font_override("font",font_UX_XS[0])
	add_theme_font_size_override("font_size",font_UX_XS[1])
	add_theme_color_override("font_color",font_UX_XS[2])
	
	add_theme_color_override("font_outline_color",FontManager.UX_color)
	add_theme_constant_override("outline_size",FontManager.UX_outline)
	
	
	panel_name = get_parent().name
	i = panel_name.to_int()
	weapon_list = WeaponsManager.weapons
	

func _process(_delta: float) -> void:
	if i < weapon_list.size():
		weapon = weapon_list[i]
	if weapon:
		if weapon.is_equiped:
			if weapon.current_level < weapon.max_level:
				set_text(str(weapon.current_level))
			else :
				set_text("Max")
	else: set_text(str(""))
	
	
