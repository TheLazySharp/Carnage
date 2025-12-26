extends Panel

var weapon_list: Array
var weapon: WeaponData
var unequiped_weapons :Array
var new_weapon: WeaponData

var resource_slot:=""
var weapon_slot:=""
var i: int
var j: int
var resource: ItemData

var levelup_cost: int

@onready var icon: TextureRect = $Icon
@onready var label: Label = $Label
@onready var no_item_mask: ColorRect = $NoItemMask



func _ready() -> void:
	WeaponsManager.new_weapon_data.connect(_update_weapons_list)
	resource_slot = name
	i = resource_slot.to_int()
	
	weapon_slot = get_parent().get_parent().get_parent().name
	j = weapon_slot.to_int()
	
	weapon_list = WeaponsManager.weapons



func _process(_delta: float) -> void:
	if j < weapon_list.size():
		weapon = weapon_list[j]
		if i < weapon.resources.size():
			resource = weapon.resources[i][0]
		
	elif j == weapon_list.size():
		weapon = new_weapon
		if weapon:
			if i < weapon.resources.size():
				resource = weapon.resources[i][0]
		
	if weapon:
		icon.texture = resource.icon
		label.text = str(weapon.resources[i][1])
		levelup_cost = weapon.resources[i][1]
		if weapon.resources[i][1] > resource.quantity:
			no_item_mask.show()
		else : no_item_mask.hide()
	
func _update_weapons_list(new_weapon_to_equiped : WeaponData, new_weapons_list : Array,_weapon_show : bool):
	new_weapon = new_weapon_to_equiped
	unequiped_weapons = new_weapons_list
