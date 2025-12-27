extends Label

var weapon_list: Array
var unequiped_weapons :Array
var weapon: WeaponData
var new_weapon: WeaponData

var panel_name:=""
var i: int


func _ready() -> void:
	WeaponsManager.new_weapon_data.connect(_update_weapons_list)
	panel_name = get_parent().get_parent().name
	i = panel_name.to_int()
	weapon_list = WeaponsManager.weapons
	

func _process(_delta: float) -> void:
	if i < weapon_list.size():
		weapon = weapon_list[i]
	elif i == weapon_list.size():
		weapon = new_weapon
	if weapon:
		set_text(weapon.weapon_name)


func _update_weapons_list(new_weapon_to_equiped : WeaponData, new_weapons_list : Array,_weapon_show : bool):
	new_weapon = new_weapon_to_equiped
	unequiped_weapons = new_weapons_list
