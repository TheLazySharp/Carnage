extends Node

const AXE = preload("uid://m78cavmqijx3")
const BOW = preload("uid://bsa4806plmw2s")
const ARROW = preload("uid://b8nw2s85q3f0a")
const AUTO_HEAL = preload("uid://dndeopvupbih1")
const SLINGSHOT = preload("uid://ewkqgn8g8vxg")
const STONE_AMMO = preload("uid://e1uwi0uago1h")


var weapon_scenes: Array[Array]


var weapons : Array[WeaponData]
var unequipped_weapons: Array[WeaponData]

var weapon : WeaponData
var player_current_level: int

signal new_weapon_data(new_weapon: WeaponData, weapon_list : Array, weapon_show: bool)

func _ready() -> void:
	XPManager.update_level.connect(shuffle_new_weapon)
	load_weapons()



func load_weapons():
	init_weapon(BOW)
	init_weapon(ARROW)
	locked_weapon(SLINGSHOT)
	locked_weapon(AXE)
	locked_weapon(AUTO_HEAL)
	weapon_scenes.append(["bow", "uid://3g0m43hcvlsk", preload("uid://3g0m43hcvlsk")])
	weapon_scenes.append(["arrow", "uid://bjuws4ysoivbu", preload("uid://bjuws4ysoivbu")])
	weapon_scenes.append(["axe", "uid://dh2o1j6s8uxlw", preload("uid://dh2o1j6s8uxlw")])
	weapon_scenes.append(["auto_heal", "uid://btqhj866y1b7a", preload("uid://btqhj866y1b7a")])
	weapon_scenes.append(["slingshot", "uid://bf606njwyoo0l", preload("uid://bf606njwyoo0l")])
	weapon_scenes.append(["stone", "uid://dww6b787qn3x0", preload("uid://dww6b787qn3x0")])
	



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
	if player_current_level % 2 == 0 : 
		if unequipped_weapons.size()>0:
			unequipped_weapons.shuffle()
			emit_signal("new_weapon_data", unequipped_weapons[0], unequipped_weapons, true)
	else: return


func unload() -> void:
	for i in weapons.size():
		weapons[i].current_level = 0
	weapons.clear()
	unequipped_weapons.clear()
	#CHECK SI BESOIN DE INIT DE NOUVEAU
