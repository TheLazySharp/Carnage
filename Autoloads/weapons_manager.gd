extends Node

#RESOURCES
const BULLET = preload("uid://b8nw2s85q3f0a")
const REVOLVER = preload("uid://ewkqgn8g8vxg")
const MINIGUN = preload("uid://byammqyru2apq")
const MG_BULLET = preload("uid://tmw3kk1tg1re")
const MINE_LAUNCHER = preload("uid://cxd60bmbatyvi")
const LANDMINE = preload("uid://cve8xcjafip0")
const EMPTY_AMMO = preload("uid://dc7hb24vr2x6r")
const BASEBALLBAT = preload("uid://kc8u8rovj5ox")
const FLAME_LAUNCHER = preload("uid://bgv4w4g2bvoby")
const FLAME = preload("uid://c5l0xm4m5tt65")
const BAT_HANDLER = preload("uid://b6wbgylc6laab")

var weapon_scenes: Array[Array] = []
var weapons : Array[WeaponData] = []
var unequipped_weapons: Array[WeaponData] = []
var ammunitions : Array[WeaponData] = []
var weapon : WeaponData
var player_current_level: int
var game_over : bool = false

enum Type {
	SHORT_RANGE,
	LONG_RANGE,
	EXPLOSIVE,
	SINGLE_SHOT,
	BURST_SHOT,
	ELEMENTAL,
	N_A
}

var short_range_weapons : Array[WeaponData] = []
var long_range_weapons : Array[WeaponData] = []
var explosive_weapons : Array[WeaponData] = []
var single_shot_weapons : Array[WeaponData] = []
var burst_shot_weapons : Array[WeaponData] = []
var elemental_weapons : Array[WeaponData] = []

var WEAPONS_TYPES : Dictionary = {
	Type.SHORT_RANGE : short_range_weapons,
	Type.LONG_RANGE : long_range_weapons,
	Type.EXPLOSIVE : explosive_weapons,
	Type.SINGLE_SHOT : single_shot_weapons,
	Type.BURST_SHOT : burst_shot_weapons,
	Type.ELEMENTAL : elemental_weapons,
	Type.N_A : [null]
}

func _ready() -> void:
	SignalManager.game_is_over.connect(_on_game_over)
	


func load_weapons() -> void:
	locked_weapon(REVOLVER)
	locked_weapon(MINIGUN)
	locked_weapon(FLAME_LAUNCHER)
	locked_weapon(MINE_LAUNCHER)
	locked_weapon(BAT_HANDLER)
	weapon_scenes.append(["revolver", "uid://bf606njwyoo0l", preload("uid://bf606njwyoo0l")])
	weapon_scenes.append(["bullet", "uid://dww6b787qn3x0", preload("uid://dww6b787qn3x0")])
	weapon_scenes.append(["minigun_bullet", "uid://doe8o0sd0xuas", preload("uid://doe8o0sd0xuas")])
	weapon_scenes.append(["minigun", "uid://c6wus6ofti85w", preload("uid://c6wus6ofti85w")])
	weapon_scenes.append(["flame", "uid://baidslgub6j8k", preload("uid://baidslgub6j8k")])
	weapon_scenes.append(["flame_launcher", "uid://cio3uws5861ij", preload("uid://cio3uws5861ij")])
	weapon_scenes.append(["mine_launcher", "uid://c8ohbftuu83c8", preload("uid://c8ohbftuu83c8")])
	weapon_scenes.append(["landmine", "uid://b6sojfyjbslm1", preload("uid://b6sojfyjbslm1")])
	weapon_scenes.append(["baseballbat", "uid://c5g74aadec237", preload("uid://c5g74aadec237")])
	weapon_scenes.append(["bat_handler", "uid://cv14lhvp1mlqs", preload("uid://cv14lhvp1mlqs")])

	
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

func equip_weapon(new_weapon: WeaponData) -> void:
	for i in weapon_scenes.size():
		if weapon_scenes[i][1] == new_weapon.weapon_scene_uid:
			var new_weapon_scene : Node2D = weapon_scenes[i][2].instantiate()
			init_weapon(new_weapon)
			get_node("/root/World/Car/Weapons").add_child(new_weapon_scene)
			break

func equip_ammo() -> void:
	if !weapons.is_empty() and ammunitions.is_empty():
		for i in weapons.size():
			var weapon_to_reload : WeaponData = weapons[i]
			if weapon_to_reload.weapon_ammo_res !=null:
				init_ammo(weapon_to_reload.weapon_ammo_res)

func init_weapon(new_weapon: WeaponData) -> void:
	new_weapon.is_equiped = true
	new_weapon.weapon_is_active = true
	weapons.append(new_weapon)
	new_weapon.equipped_sessions.append(TimeManager.active_time)
	if !unequipped_weapons.is_empty():
		for i in unequipped_weapons.size():
			if unequipped_weapons[i] == new_weapon:
				unequipped_weapons.remove_at(i)
				break
	if new_weapon.weapon_ammo_res !=null:
		init_ammo(new_weapon.weapon_ammo_res)
	new_weapon.init_stats()
	add_weapon_type_to_array(new_weapon)


func init_ammo(new_ammo : WeaponData) -> void: 
	new_ammo.is_equiped = true
	new_ammo.weapon_is_active = true
	ammunitions.append(new_ammo)
	new_ammo.init_stats()
	add_weapon_type_to_array(new_ammo)


func locked_weapon(new_weapon: WeaponData) -> void:
	new_weapon.is_equiped = false
	unequipped_weapons.append(new_weapon)


func unequip_ammo() -> void:
	ammunitions.clear()
	
func unequip_weapon(p_weapon : WeaponData) -> void : 
	p_weapon.total_equipped_time += p_weapon.get_active_duration()
	

func unload() -> void:
	for i in weapons.size():
		weapons[i].current_level = 0
	weapons.clear()
	unequipped_weapons.clear()
	weapon_scenes.clear()
	ammunitions.clear()
	short_range_weapons.clear()
	long_range_weapons.clear()
	explosive_weapons.clear()
	single_shot_weapons.clear()
	burst_shot_weapons.clear()
	elemental_weapons.clear()


func instantiate_weapons() -> void:
	for i in weapon_scenes.size():
		var scene : Array =  weapon_scenes[i]
		for j in weapons.size():
			if scene[1] == weapons[j].weapon_scene_uid:
				var new_weapon_scene : Node2D = weapon_scenes[i][2].instantiate()
				get_node("/root/World/Car/Weapons").add_child(new_weapon_scene)


func activate_weapons(active: bool)-> void:
	if !weapons.is_empty():
		for i in weapons.size():
			weapons[i].weapon_is_active = active


func _on_game_over(game_is_over : bool) -> void : 
	game_over = game_is_over
	
func add_weapon_type_to_array(new_weapon : WeaponData) -> void : 
	var type1 : Type = new_weapon.type_1
	var type2 : Type = new_weapon.type_2
	
	for type : Type in WEAPONS_TYPES:
		if type1 == type or type2 == type:
			WEAPONS_TYPES[type].append(new_weapon)

func get_weapon_total_dmg(p_weapon : WeaponData) -> int :
	if p_weapon.weapon_ammo_scene != null:
		return p_weapon.weapon_ammo_res.total_damages_dealt
	else : 
		return p_weapon.total_damages_dealt

func get_weapon_dps(p_weapon : WeaponData) -> float :
	var duration : float = TimeManager.active_time - p_weapon.get_active_duration()
	if duration <= 0:
		duration = TimeManager.active_time
	if p_weapon.weapon_ammo_scene != null:
		return p_weapon.weapon_ammo_res.total_damages_dealt / duration
	else : 
		return p_weapon.total_damages_dealt / duration

func get_total_game_dmg() -> int :
	var total : int = 0
	for i in weapons.size():
		total += get_weapon_total_dmg(weapons[i])
	return total


func init_god_mod()-> void : 
	init_weapon(FLAME_LAUNCHER)
	init_weapon(MINIGUN)
	init_weapon(BAT_HANDLER)
	init_weapon(MINE_LAUNCHER)

func god_mod_full_power() -> void : 
	var god_mod : Modifier = Modifier.new(5,Modifier.Type.FLAT,"weapons manager god mod")
	for i in weapons.size():
		weapons[i].nb_projectile.add_modifier(god_mod)
