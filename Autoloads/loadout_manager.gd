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

var sandbox_active : bool = false

func _ready() -> void:
	SignalManager.sandbox_mode.connect(_on_sandbox_mode)

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

func _on_sandbox_mode() -> void : 
	sandbox_active = true
	
func unload() -> void : 
	sandbox_active = false
