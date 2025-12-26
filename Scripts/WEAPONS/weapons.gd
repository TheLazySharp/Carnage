extends Node2D

var weapons : Array
var weapon_scenes : Array

#@onready var weapons_node: Node2D = $"."

func _ready() -> void:
	weapons = WeaponsManager.weapons
	weapon_scenes = WeaponsManager.weapon_scenes
	
	for i in weapons.size():
		for j in weapon_scenes.size():
			if weapon_scenes[j][1] == weapons[i].weapon_scene_uid:
				var equiped_weapon : Node2D = weapon_scenes[j][2].instantiate()
				add_child(equiped_weapon)

	print("WEAPONS :")
	for i in weapons.size():
		print(weapons[i].weapon_name)
	print("UNEQUIPPED :")
	for i in WeaponsManager.unequipped_weapons.size():
		print(WeaponsManager.unequipped_weapons[i].weapon_name)
