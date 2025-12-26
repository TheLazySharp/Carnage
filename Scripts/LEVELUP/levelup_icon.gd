extends TextureRect

var weapon_list: Array
var weapon: WeaponData
var unequiped_weapons :Array
var new_weapon: WeaponData


var icon_name:=""
var i: int


func _ready() -> void:
	WeaponsManager.new_weapon_data.connect(_update_weapons_list)
	icon_name = get_parent().name
	i = icon_name.to_int()
	weapon_list = WeaponsManager.weapons
	

func _process(_delta: float) -> void:
	if i < weapon_list.size():
		weapon = weapon_list[i]
	elif i == weapon_list.size():
		weapon = new_weapon
	if weapon:
		self.texture = weapon.weapon_icon

func _update_weapons_list(new_weapon_to_equiped : WeaponData, new_weapons_list : Array,_weapon_show : bool):
	new_weapon = new_weapon_to_equiped
	unequiped_weapons = new_weapons_list
