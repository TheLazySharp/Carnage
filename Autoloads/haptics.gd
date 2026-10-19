extends Node
## Autoload "Haptics": controller vibration (Steam Deck, gamepads).
## One place to mute or scale every rumble (future options menu: set_enabled)

const REFRESH_INTERVAL : float = 0.08  # continuous rumble is re-sent this often
const RUMBLE_ON_PC : bool = false      # true: rumble on PC pads too (off by default: cheap pads rumble badly)

var enabled : bool = true  # set in _ready: on for the Steam Deck, RUMBLE_ON_PC elsewhere
var intensity : float = 1.0  # global scale

var continuous_weak : float = 0.0
var continuous_strong : float = 0.0
var pulse_time_left : float = 0.0
var refresh_left : float = 0.0


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	enabled = is_steam_deck() or RUMBLE_ON_PC


## SteamOS sets this environment variable for games launched through Steam on the Deck
func is_steam_deck() -> bool:
	return OS.get_environment("SteamDeck") == "1"


## For the options menu: turning it off also stops a rumble in progress
func set_enabled(value : bool) -> void:
	enabled = value
	if !enabled:
		stop()


## Short one-shot vibration, has priority over the continuous one
func pulse(weak : float, strong : float, duration : float) -> void:
	if !enabled:
		return
	pulse_time_left = duration
	_vibrate(weak, strong, duration)


## Vibration kept on until set back to 0 (drift, engine...)
func set_continuous(weak : float, strong : float) -> void:
	continuous_weak = weak
	continuous_strong = strong


func stop() -> void:
	continuous_weak = 0.0
	continuous_strong = 0.0
	pulse_time_left = 0.0
	for device : int in Input.get_connected_joypads():
		Input.stop_joy_vibration(device)


func _process(delta : float) -> void:
	if pulse_time_left > 0.0:
		pulse_time_left -= delta
		return
	refresh_left -= delta
	if refresh_left > 0.0:
		return
	refresh_left = REFRESH_INTERVAL
	if !enabled or (continuous_weak <= 0.01 and continuous_strong <= 0.01):
		return  # the last vibration expires by itself
	# Slightly longer than the refresh so the rumble never drops between two calls
	_vibrate(continuous_weak, continuous_strong, REFRESH_INTERVAL * 1.5)


func _vibrate(weak : float, strong : float, duration : float) -> void:
	var scaled_weak : float = clampf(weak * intensity, 0.0, 1.0)
	var scaled_strong : float = clampf(strong * intensity, 0.0, 1.0)
	for device : int in Input.get_connected_joypads():
		Input.start_joy_vibration(device, scaled_weak, scaled_strong, duration)


func _on_game_paused(game_on_pause : bool) -> void:
	if game_on_pause:
		stop()
