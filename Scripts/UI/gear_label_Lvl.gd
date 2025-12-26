extends Label

var weapon_list: Array
var weapon: WeaponData

var panel_name:=""
var i: int

func _ready() -> void:
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
	
	
