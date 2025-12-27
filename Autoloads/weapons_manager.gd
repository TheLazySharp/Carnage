extends Node

const BULLET = preload("uid://b8nw2s85q3f0a")
const REVOLVER = preload("uid://ewkqgn8g8vxg")
const MINIGUN = preload("uid://byammqyru2apq")
const MG_BULLET = preload("uid://tmw3kk1tg1re")




var weapon_scenes: Array[Array]

var weapons : Array[WeaponData]
var unequipped_weapons: Array[WeaponData]

var weapon : WeaponData
var player_current_level: int

signal new_weapon_data(new_weapon: WeaponData, weapon_list : Array, weapon_show: bool)

func _ready() -> void:
	XPManager.update_level.connect(shuffle_new_weapon)
	#load_weapons()



func load_weapons():
	locked_weapon(REVOLVER)
	locked_weapon(MINIGUN)
	weapon_scenes.append(["revolver", "uid://bf606njwyoo0l", preload("uid://bf606njwyoo0l")])
	weapon_scenes.append(["bullet", "uid://dww6b787qn3x0", preload("uid://dww6b787qn3x0")])
	weapon_scenes.append(["minigun_bullet", "uid://doe8o0sd0xuas", preload("uid://doe8o0sd0xuas")])
	weapon_scenes.append(["minigun", "uid://c6wus6ofti85w", preload("uid://c6wus6ofti85w")])
	
	print("INIT WEAPONS :")
	for j in weapons.size():
		print(weapons[j].weapon_name)
	print("UNEQUIPPED :")
	for k in unequipped_weapons.size():
		print(unequipped_weapons[k].weapon_name)
	if unequipped_weapons.is_empty() :
		print("empty")


func copy_weapons() -> Array :
	return weapons

func init_weapon(new_weapon: WeaponData) -> void:
	new_weapon.is_equiped = true
	weapons.append(new_weapon)

func locked_weapon(new_weapon: WeaponData):
	new_weapon.is_equiped = false
	unequipped_weapons.append(new_weapon)

func equip_weapon(new_weapon: WeaponData) -> void:
	for i in weapon_scenes.size():
		print(weapon_scenes[i][1])
		print(new_weapon.weapon_scene_uid)
		if weapon_scenes[i][1] == new_weapon.weapon_scene_uid:
			var new_weapon_scene : Node2D = weapon_scenes[i][2].instantiate()
			get_node("/root/World/Car/Weapons").add_child(new_weapon_scene)
			init_weapon(new_weapon)
			unequipped_weapons.remove_at(0)
			
			if new_weapon.weapon_ammo_res !=null and new_weapon.weapon_ammo_scene != null:
				init_weapon(new_weapon.weapon_ammo_res)
				print(new_weapon.weapon_ammo_res.weapon_name," is equiped : ", new_weapon.weapon_ammo_res.is_equiped)


			print(new_weapon.weapon_name," is equiped : ", new_weapon.is_equiped)
			
			print("MAJ WEAPONS :")
			for j in weapons.size():
				print(weapons[j].weapon_name)
			print("UNEQUIPPED :")
			for k in unequipped_weapons.size():
				print(unequipped_weapons[k].weapon_name)
			if unequipped_weapons.is_empty() :
				print("empty")
			
			return

func equip_ammo(weapon_with_ammo: WeaponData) -> PackedScene:
	var ammo : PackedScene = weapon_with_ammo.weapon_ammo_scene
	return ammo

func unequip_weapon(_old_weapon: WeaponData) -> void:
	pass
	

func shuffle_new_weapon(new_current_level):
	player_current_level = new_current_level
	#if player_current_level % 2 == 0 : 
	if unequipped_weapons.size()>0:
		unequipped_weapons.shuffle()
		emit_signal("new_weapon_data", unequipped_weapons[0], unequipped_weapons, true)
	#else: return


func unload() -> void:
	for i in weapons.size():
		weapons[i].current_level = 0
	weapons.clear()
	unequipped_weapons.clear()
	#CHECK SI BESOIN DE INIT DE NOUVEAU
