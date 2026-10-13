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
var spread_half: float = 0.0  # radians, streams only: random deviation around each direction

## Returns false when the maneuver has no projectile pattern (zone maneuvers)
func start(data: WeaponData, maneuver_type: ManeuverManager.Type, intensity: float, drift_level: int, is_amplified: bool, attack_angle: float, combo_multiplier: float) -> bool:
	var pattern: Vector3 = ManeuverManager.get_pattern(maneuver_type)
	if pattern.z < 0.0:
		return false
	arc = pattern.y
	center_angle = attack_angle
	directions = data.get_salvo_count(maneuver_type, intensity, drift_level, is_amplified, combo_multiplier)
	var shots_per_direction: int = data.get_shots_per_direction()
	total = directions * shots_per_direction
	shots_left = total
	if shots_per_direction == 1:
		# Sweep: one direction per tick, spread over the maneuver duration
		shots_per_tick = 1
		interval = pattern.z / directions
		spread_half = 0.0
	else:
		# Streams: every direction at each tick, at the weapon fire rate, inside a cone
		shots_per_tick = directions
		interval = data.get_stream_interval()
		spread_half = deg_to_rad(data.stream_spread_degrees) * 0.5
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
	var angle: float = ManeuverManager.get_spread_angle(direction_index, directions, arc, center_angle)
	if spread_half > 0.0:
		angle += randf_range(-spread_half, spread_half)
	return angle
