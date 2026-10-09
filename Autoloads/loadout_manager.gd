extends Node
## Run loadout: maneuvers owned by the car and the weapon placed on each maneuver.
## Reset at the start of each run

var car : CarData = null
var owned_maneuvers : Array[ManeuverManager.Type] = []
var weapon_by_maneuver : Dictionary[ManeuverManager.Type, WeaponData] = {}
var pending_weapons : Array[WeaponData] = []


func start_run(p_car : CarData) -> void:
	car = p_car
	owned_maneuvers = p_car.base_maneuvers.duplicate()
	weapon_by_maneuver.clear()
	pending_weapons.clear()


func owns(maneuver_type : ManeuverManager.Type) -> bool:
	# The loop is the car ultimate: always available
	return maneuver_type == ManeuverManager.Type.LOOP or owned_maneuvers.has(maneuver_type)


func unlock(maneuver_type : ManeuverManager.Type) -> void:
	if !owned_maneuvers.has(maneuver_type):
		owned_maneuvers.append(maneuver_type)


func get_weapon(maneuver_type : ManeuverManager.Type) -> WeaponData:
	return weapon_by_maneuver.get(maneuver_type, null)


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


func add_pending_weapon(weapon : WeaponData) -> void:
	if weapon != null and !pending_weapons.has(weapon):
		pending_weapons.append(weapon)


## Temporary, until the build screen exists: places the pending weapons on free owned maneuvers,
## their preferred maneuvers first
func auto_assign_pending() -> void:
	for weapon : WeaponData in pending_weapons:
		var candidates : Array[ManeuverManager.Type] = weapon.assigned_maneuvers.duplicate()
		candidates.append_array(owned_maneuvers)
		for maneuver_type : ManeuverManager.Type in candidates:
			if count_assignments(weapon) >= car.maneuvers_per_weapon:
				break
			if owned_maneuvers.has(maneuver_type) and !weapon_by_maneuver.has(maneuver_type):
				weapon_by_maneuver[maneuver_type] = weapon
	pending_weapons.clear()
