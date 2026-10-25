extends Node
## Run loadout: maneuvers owned by the car and the weapon placed on each maneuver.
## Reset at the start of each run

var car : CarData = null
var owned_maneuvers : Array[ManeuverManager.Type] = []
var weapon_by_maneuver : Dictionary[ManeuverManager.Type, WeaponData] = {}
var pending_weapons : Array[WeaponData] = []
# Power of each maneuver for this run (base from ManeuverManager.get_power, modified by level-ups and charms)
var maneuver_power : Dictionary[ManeuverManager.Type, Statistic] = {}
# A maneuver bought at the shop: the loadout panel opens on the roadmap to place a weapon on it
var has_new_maneuver : bool = false
## Sandbox only: false = no weapon fires (clean maneuver captures). Kept for the whole session
var sandbox_weapons_enabled : bool = true
var sandbox_active : bool = false


## Every maneuver resource (shop, tutorial, maneuver menu, names on screen).
## Loaded at runtime: no preload cycle with resources referencing autoloads
const MANEUVER_DATA_UIDS : Array[String] = [
	"uid://b4o7xjo8isqj0", #burnout
	"uid://b8dwx3opcyu68", #donut
	"uid://bie426kp6jx7a", #reverse 180
	"uid://d37q3bjdh6vpc", #horn
	"uid://boboqx2yj8bl7", #short drift
	"uid://cht1vuqnvh1ny", #spin 360
	"uid://h5gvivokva2o", #U turn
	"uid://bo683su45ub5v", #loop
]
var maneuver_data_by_type : Dictionary[ManeuverManager.Type, ManeuverData] = {}





func _ready() -> void:
	SignalManager.sandbox_mode.connect(_on_sandbox_mode)
	_load_maneuver_catalog()

func start_run(p_car : CarData) -> void:
	car = p_car
	owned_maneuvers = p_car.base_maneuvers.duplicate()
	weapon_by_maneuver.clear()
	has_new_maneuver = false
	pending_weapons.clear()
	maneuver_power.clear()
	for maneuver_type : ManeuverManager.Type in ManeuverManager.Type.values():
		maneuver_power[maneuver_type] = Statistic.new(ManeuverManager.get_power(maneuver_type))
	if is_test_mode():
		for maneuver_type : ManeuverManager.Type in ManeuverManager.Type.values():
			unlock(maneuver_type)
		has_new_maneuver = false

func _load_maneuver_catalog() -> void:
	maneuver_data_by_type.clear()
	for uid : String in MANEUVER_DATA_UIDS:
		var data : ManeuverData = load(uid) as ManeuverData
		if data == null:
			push_warning("[LoadoutManager] maneuver resource not found: " + uid)
			continue
		maneuver_data_by_type[data.maneuver_type] = data


func get_maneuver_data(maneuver_type : ManeuverManager.Type) -> ManeuverData:
	return maneuver_data_by_type.get(maneuver_type, null)


## Name shown to the player: translated name of the resource, technical name as a fallback
func get_maneuver_display_name(maneuver_type : ManeuverManager.Type) -> String:
	var data : ManeuverData = get_maneuver_data(maneuver_type)
	if data != null and data.name_key != "":
		return tr(data.name_key)
	return ManeuverManager.get_maneuver_name(maneuver_type)


func is_test_mode() -> bool:
	return sandbox_active


func owns(maneuver_type : ManeuverManager.Type) -> bool:
	# The loop is the car ultimate: always available
	return maneuver_type == ManeuverManager.Type.LOOP or owned_maneuvers.has(maneuver_type)


func unlock(maneuver_type : ManeuverManager.Type) -> void:
	if !owned_maneuvers.has(maneuver_type):
		owned_maneuvers.append(maneuver_type)
		has_new_maneuver = true


func get_weapon(maneuver_type : ManeuverManager.Type) -> WeaponData:
	# Sandbox with weapons off: every maneuver is unarmed, the weapons stay equipped but never fire
	if sandbox_active and !sandbox_weapons_enabled:
		return null
	return weapon_by_maneuver.get(maneuver_type, null)

## Falls back on the base power when no run is started (map test scenes)
func get_maneuver_power(maneuver_type : ManeuverManager.Type) -> float:
	if maneuver_power.has(maneuver_type):
		return maneuver_power[maneuver_type].get_value()
	return ManeuverManager.get_power(maneuver_type)

func count_assignments(weapon : WeaponData) -> int:
	var count : int = 0
	for assigned : WeaponData in weapon_by_maneuver.values():
		if assigned == weapon:
			count += 1
	return count


## Returns false when the move breaks a rule (maneuver not owned, weapon already on its max).
## Replaces the weapon previously on this maneuver
func assign(maneuver_type : ManeuverManager.Type, weapon : WeaponData) -> bool:
	if !owned_maneuvers.has(maneuver_type):
		return false
	if get_weapon(maneuver_type) != weapon and count_assignments(weapon) >= car.maneuvers_per_weapon:
		return false
	weapon_by_maneuver[maneuver_type] = weapon
	return true


func unassign(maneuver_type : ManeuverManager.Type) -> void:
	weapon_by_maneuver.erase(maneuver_type)

## Tutorial only: one weapon on every owned maneuver, ignoring the per-weapon limit
func assign_everywhere(weapon : WeaponData) -> void:
	for maneuver_type : ManeuverManager.Type in owned_maneuvers:
		weapon_by_maneuver[maneuver_type] = weapon

func add_pending_weapon(weapon : WeaponData) -> void:
	if weapon != null and !pending_weapons.has(weapon):
		pending_weapons.append(weapon)


## Places the pending weapons on free owned maneuvers, their preferred maneuvers first
func auto_assign_pending() -> void:
	# Test mode: each new weapon goes on every maneuver (the newest one wins)
	if is_test_mode():
		for weapon : WeaponData in pending_weapons:
			assign_everywhere(weapon)
		pending_weapons.clear()
		return
	for weapon : WeaponData in pending_weapons:
		var candidates : Array[ManeuverManager.Type] = weapon.assigned_maneuvers.duplicate()
		candidates.append_array(owned_maneuvers)
		for maneuver_type : ManeuverManager.Type in candidates:
			if count_assignments(weapon) >= car.maneuvers_per_weapon:
				break
			if owned_maneuvers.has(maneuver_type) and !weapon_by_maneuver.has(maneuver_type):
				weapon_by_maneuver[maneuver_type] = weapon
	pending_weapons.clear()

func _unhandled_input(event : InputEvent) -> void:
	if sandbox_active and event.is_action_pressed("sandbox_toggle_weapons"):
		sandbox_weapons_enabled = !sandbox_weapons_enabled
		print("[Sandbox] weapons ", "ON" if sandbox_weapons_enabled else "OFF")

func _on_sandbox_mode() -> void : 
	sandbox_active = true
	
func unload() -> void : 
	sandbox_active = false
