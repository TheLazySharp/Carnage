extends Node
## Autoload "Juice": global feel services (time effects).
## All tuning lives in JuiceSettings (res://juice/juice_settings.tres).

const SETTINGS = preload("uid://dbohpdgym7v6q")

var last_car_hit_time : float = -1000.0
var last_hit_stop_time : float = -1000.0
var hit_stop_active : bool = false
var time_scale_before_stop : float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the restore timer must run whatever happens


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


## Slows the whole game for 'duration' real seconds, then restores the previous time scale
func hit_stop(duration : float) -> void:
	if hit_stop_active or get_tree().paused:
		return
	hit_stop_active = true
	last_hit_stop_time = Time.get_ticks_msec() / 1000.0
	time_scale_before_stop = Engine.time_scale
	Engine.time_scale = SETTINGS.hit_stop_time_scale
	# ignore_time_scale = true: the timer counts real seconds
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = time_scale_before_stop
	hit_stop_active = false
