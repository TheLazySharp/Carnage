extends Node

#RESOURCES
const BULLET = preload("uid://b8nw2s85q3f0a")
const REVOLVER = preload("uid://ewkqgn8g8vxg")
const MINIGUN = preload("uid://byammqyru2apq")
const MG_BULLET = preload("uid://tmw3kk1tg1re")
const FLAMER = preload("uid://c5l0xm4m5tt65")
const MINE_LAUNCHER = preload("uid://cxd60bmbatyvi")
const LANDMINE = preload("uid://cve8xcjafip0")
const EMPTY_AMMO = preload("uid://dc7hb24vr2x6r")


var weapon_scenes: Array[Array]
var weapons : Array[WeaponData]
var unequipped_weapons: Array[WeaponData]
var ammunitions : Array[WeaponData]
var weapon : WeaponData
var player_current_level: int
var game_over : bool = false

func _ready() -> void:
	SignalManager.game_is_over.connect(_on_game_over)
	

func _process(_delta: float) -> void:
	if !game_over:
		return
	unload()

func load_weapons() -> void:
	locked_weapon(REVOLVER)
	locked_weapon(MINIGUN)
	locked_weapon(FLAMER)
	locked_weapon(MINE_LAUNCHER)
	weapon_scenes.append(["revolver", "uid://bf606njwyoo0l", preload("uid://bf606njwyoo0l")])
	weapon_scenes.append(["bullet", "uid://dww6b787qn3x0", preload("uid://dww6b787qn3x0")])
	weapon_scenes.append(["minigun_bullet", "uid://doe8o0sd0xuas", preload("uid://doe8o0sd0xuas")])
	weapon_scenes.append(["minigun", "uid://c6wus6ofti85w", preload("uid://c6wus6ofti85w")])
	weapon_scenes.append(["flamer", "uid://baidslgub6j8k", preload("uid://baidslgub6j8k")])
	weapon_scenes.append(["mine_launcher", "uid://c8ohbftuu83c8", preload("uid://c8ohbftuu83c8")])
	weapon_scenes.append(["landmine", "uid://b6sojfyjbslm1", preload("uid://b6sojfyjbslm1")])
	##print("weapons loaded")

	
func test_weapons() ->void:
	#equip_weapon(FLAMER)
	#weapons[0].dmg = 10
	#check_weapons()
	pass
	
	
func check_weapons() -> void:
	print("EQUIPPED WEAPONS :")
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
	new_weapon.weapon_is_active = true
	weapons.append(new_weapon)
	if !unequipped_weapons.is_empty():
		for i in unequipped_weapons.size():
			if unequipped_weapons[i] == new_weapon:
				unequipped_weapons.remove_at(i)
				break
	if new_weapon.weapon_ammo_res !=null:
		init_ammo(new_weapon.weapon_ammo_res)

func init_ammo(new_ammo : WeaponData) -> void: 
	new_ammo.is_equiped = true
	new_ammo.weapon_is_active = true
	ammunitions.append(new_ammo)


func locked_weapon(new_weapon: WeaponData) -> void:
	new_weapon.is_equiped = false
	unequipped_weapons.append(new_weapon)

func equip_weapon(new_weapon: WeaponData) -> void:
	for i in weapon_scenes.size():
		if weapon_scenes[i][1] == new_weapon.weapon_scene_uid:
			var new_weapon_scene : Node2D = weapon_scenes[i][2].instantiate()
			get_node("/root/World/Car/Weapons").add_child(new_weapon_scene)
			init_weapon(new_weapon)
			break


func equip_ammo() -> void:
	if !weapons.is_empty() and ammunitions.is_empty():
		for i in weapons.size():
			var weapon_to_reload : WeaponData = weapons[i]
			#if weapon_to_reload.weapon_ammo_res !=null and weapon_to_reload.weapon_ammo_scene != null:
			if weapon_to_reload.weapon_ammo_res !=null:
				init_ammo(weapon_to_reload.weapon_ammo_res)
				


func unequip_ammo() -> void:
	ammunitions.clear()
	

#func shuffle_new_weapon(new_current_level : int) -> void:
	#player_current_level = new_current_level
	##if player_current_level % 2 == 0 : 
	#if unequipped_weapons.size()>0:
		#unequipped_weapons.shuffle()
		#emit_signal("new_weapon_data", unequipped_weapons[0], unequipped_weapons, true)
	##else: return


func unload() -> void:
	for i in weapons.size():
		weapons[i].current_level = 0
	weapons.clear()
	unequipped_weapons.clear()
	weapon_scenes.clear()
	ammunitions.clear()



func reinit_weapons() -> void:
	for i in weapon_scenes.size():
		var scene : Array =  weapon_scenes[i]
		for j in weapons.size():
			if scene[1] == weapons[j].weapon_scene_uid:
				var new_weapon_scene : Node2D = weapon_scenes[i][2].instantiate()
				get_node("/root/World/Car/Weapons").add_child(new_weapon_scene)
				print(new_weapon_scene," is reinit")



func activate_weapons(active: bool)-> void:
	if !weapons.is_empty():
		for i in weapons.size():
			weapons[i].weapon_is_active = active


func weapon_stat(weap : WeaponData) -> void:
	if weap.weapon_ammo_res != null:
		weap.dmg = weap.weapon_ammo_res.dmg

func _on_game_over(game_is_over : bool) -> void : 
	game_over = game_is_over
