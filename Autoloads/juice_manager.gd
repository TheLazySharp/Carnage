extends Node
## Autoload "Juice": global feel services (time effects).
## All tuning lives in JuiceSettings (res://juice/juice_settings.tres).

const SETTINGS = preload("uid://dbohpdgym7v6q")

var last_car_hit_time : float = -1000.0
var last_hit_stop_time : float = -1000.0
var hit_stop_active : bool = false
var last_drift_hit_juice_time : float = -1000.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the restore timer must run whatever happens
	SignalManager.maneuver_performed.connect(_on_maneuver_performed)

## Called once per car -> enemy hit. Global hit-stop only on a strong hit
## that follows a calm moment: never repeated inside a horde.
func on_car_hit(car_speed_ratio : float) -> void:
	var now : float = Time.get_ticks_msec() / 1000.0
	var calm_time : float = now - last_car_hit_time
	last_car_hit_time = now

	if !SETTINGS.hit_stop_enabled:
		return
	if car_speed_ratio < SETTINGS.hit_stop_min_speed_ratio:
		return
	if calm_time < SETTINGS.hit_stop_isolation_time:
		return
	if now - last_hit_stop_time < SETTINGS.hit_stop_cooldown:
		return
	hit_stop(SETTINGS.hit_stop_duration)


## Slows the whole game for 'duration' real seconds, then back to normal speed
func hit_stop(duration : float) -> void:
	if hit_stop_active or get_tree().paused:
		return
	hit_stop_active = true
	last_hit_stop_time = Time.get_ticks_msec() / 1000.0
	Engine.time_scale = SETTINGS.hit_stop_time_scale
	# ignore_time_scale = true: the timer counts real seconds
	await get_tree().create_timer(duration, true, false, true).timeout
	# Always back to normal speed: restoring a saved value could lock the game in slow motion
	# when two freezes overlap
	Engine.time_scale = 1.0
	hit_stop_active = false
	
	## Perfect drift hit: true when the freeze / zoom / shake may play (once per cooldown, real time)
func try_drift_hit_juice() -> bool:
	var now : float = Time.get_ticks_msec() / 1000.0
	if now - last_drift_hit_juice_time < SETTINGS.drift_hit_juice_cooldown:
		return false
	last_drift_hit_juice_time = now
	return true

func _on_maneuver_performed(maneuver_type : ManeuverManager.Type, _intensity : float, _drift_level : int, _is_amplified : bool, _attack_angle : float) -> void:
	if !SETTINGS.maneuver_juice_enabled or SETTINGS.maneuver_juice_excluded.has(maneuver_type):
		return
	hit_stop(SETTINGS.maneuver_stop_duration)
