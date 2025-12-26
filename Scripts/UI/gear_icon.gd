extends TextureRect

var weapon_list: Array
var weapon: WeaponData


var icon_name:=""
var i: int


func _ready() -> void:
	icon_name = get_parent().name
	i = icon_name.to_int()
	weapon_list = WeaponsManager.weapons
	

func _process(_delta: float) -> void:
	if i < weapon_list.size():
		weapon = weapon_list[i]

	if weapon:
		self.texture = weapon.weapon_icon
