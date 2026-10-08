class_name ManeuverSalvo
extends RefCounted
## Salvo driven by a maneuver, shared by the projectile weapons (minigun, revolver, grenades).
## Directions are spread over the maneuver arc. With one shot per direction, the salvo sweeps
## the arc (one direction after the other). With several shots per direction (streams),
## every direction fires at each tick

var directions: int = 0
var shots_per_tick: int = 1
var total: int = 0
var shots_left: int = 0
var arc: float = 0.0
var center_angle: float = 0.0
var interval: float = 0.0
var timer: float = 0.0
var damage_multiplier: float = 1.0


## Returns false when the maneuver has no projectile pattern (zone maneuvers)
func start(data: WeaponData, maneuver_type: ManeuverManager.Type, intensity: float, drift_level: int, is_amplified: bool, attack_angle: float, combo_multiplier: float) -> bool:
	var pattern: Vector3 = ManeuverManager.get_pattern(maneuver_type)
	if pattern.z < 0.0:
		return false
	arc = pattern.y
	center_angle = attack_angle
	directions = data.get_salvo_count(maneuver_type, intensity, drift_level, is_amplified, combo_multiplier)
	var shots_per_direction: int = data.get_shots_per_direction()
	# Sweep: one direction per tick. Streams: every direction at each tick
	shots_per_tick = 1 if shots_per_direction == 1 else directions
	var ticks: int = directions if shots_per_direction == 1 else shots_per_direction
	total = directions * shots_per_direction
	shots_left = total
	interval = pattern.z / ticks
	timer = 0.0
	damage_multiplier = data.get_combo_damage_multiplier(combo_multiplier)
	return true


## Number of shots due this frame (an instant salvo returns them all at once)
func advance(delta: float) -> int:
	if shots_left <= 0:
		return 0
	timer -= delta
	var due: int = 0
	while timer <= 0.0 and due < shots_left:
		due += shots_per_tick
		timer += interval
	return mini(due, shots_left)


## World angle of the next shot (consumes it)
func next_angle() -> float:
	# In sweep mode the index never exceeds directions; in stream mode it cycles at each tick
	var direction_index: int = (total - shots_left) % directions
	shots_left -= 1
	return ManeuverManager.get_spread_angle(direction_index, directions, arc, center_angle)
