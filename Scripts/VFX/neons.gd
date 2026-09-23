class_name CarNeons
extends Node2D

enum Pattern { STEADY, PULSE, BLINK, RAINBOW, BEACON }

# hold_time value for effects that stay on until stop() is called
const HOLD_UNTIL_STOP : float = -1.0

# The highest active priority is displayed (ties: the most recently started effect wins)
const PRIORITY_BLOOD : int = 20
const PRIORITY_DOLLARS : int = 20
const PRIORITY_XP : int = 30
const PRIORITY_LOW_HEALTH : int = 80
const PRIORITY_BEACON : int = 100

const CHANNEL_BLOOD : StringName = &"blood"
const CHANNEL_BEACON : StringName = &"beacon"

# Debug: above everything so the tested effect is always visible
const PRIORITY_DEBUG : int = 1000
const DEBUG_NEON_NAMES : Array[StringName] = [&"blood", &"dollars", &"xp", &"beacon", &"low_health",&"idle"]
const DEBUG_DOLLARS_COLOR : Color = Color(0.1, 0.9, 0.2, 1.0)
const DEBUG_XP_PERIOD : float = 1.5


class NeonEffect:
	var channel : StringName
	var color : Color
	var pattern : Pattern
	var priority : int
	var period : float
	var start_time : float
	var expire_at : float


@onready var bloody_engine : BloodyEngine

# Brightness multiplier for all neons. Too high and the WorldEnvironment glow bleeds over the car = MAX 3.5
@export_range(0.0, 10.0, 0.05) var glow_intensity : float = 3.0:
	set(value):
		glow_intensity = value
		modulate = Color(value, value, value, 1.0)

@export var idle_visible : bool = true:
	set(value):
		idle_visible = value
		if is_node_ready():
			_start_transition()
			_wake()

@export var idle_color : Color = Color(0.6, 0.6, 0.6, 1.0)

@export var transition_time : float = 0.25

@export_range(0.0, 1.0) var pulse_min : float = 0.6

@export_group("Blood")
@export var blood_color : Color = Color(0.9, 0.08, 0.03, 1.0)
@export var blood_hold_time : float = 0.4

@export_group("Beacon")
@export var beacon_color : Color = Color(1.0, 0.8, 0.0, 1.0)
# Brightness multiplier for the beacon neon only (stacks with glow_intensity)
@export_range(0.0, 10.0, 0.05) var beacon_intensity : float = 2.0
@export var beacon_other_color : Color = Color(0.6, 0.6, 0.6, 1.0)
# Duration of the flash triggered by each beacon_pulse()
@export var beacon_flash_time : float = 0.2
# Beacon neon brightness between two flashes
@export_range(0.0, 1.0) var beacon_min : float = 0.15


@export_group("Debug")
# Simulated beep interval for the debug beacon
@export var debug_beacon_interval : float = 0.5

# Starts on idle so the first press shows blood
var _debug_index : int = DEBUG_NEON_NAMES.size() - 1
var _debug_channel : StringName = &""
var _debug_beacon_active : bool = false


var _neons : Array[ColorRect] = []
# Direction of each neon from the body center, in local space (used by the beacon)
var _neon_directions : Array[Vector2] = []
var _body_center : Vector2 = Vector2.ZERO
var _current_colors : Array[Color] = []
var _from_colors : Array[Color] = []
# StringName channel -> NeonEffect
var _effects : Dictionary = {}
var _displayed_channel : StringName = &""
var _transition_progress : float = 1.0
var _time : float = 0.0
var _beacon_target : Vector2 = Vector2.ZERO
var _beacon_last_pulse : float = -1000.0


func _enter_tree() -> void:
	# Registered before any _ready() so other nodes can find it from their own _ready()
	add_to_group(&"car_neons")


func _ready() -> void:
	if GameMaster.is_debug():
		bloody_engine = $/root/Lands/Car/BloodyEngine
	else : 
		bloody_engine = $/root/World/Car/BloodyEngine
	
	show_behind_parent = true
	modulate = Color(glow_intensity, glow_intensity, glow_intensity, 1.0)
	for child : Node in get_children():
		var neon : ColorRect = child as ColorRect
		if neon == null:
			continue
		neon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_neons.append(neon)
	_compute_neon_directions()
	_current_colors.resize(_neons.size())
	_current_colors.fill(_get_idle_color())
	_from_colors = _current_colors.duplicate()
	bloody_engine.blood_absorbed.connect(_on_blood_absorbed)
	
	_wake()


# --- Public API ---------------------------------------------------------------

## Starts or refreshes an effect. The effect lasts hold_time after the LAST call
## (HOLD_UNTIL_STOP = until stop(channel)). Calling again keeps the animation phase.
func play(channel : StringName, color : Color, pattern : Pattern, hold_time : float, priority : int, period : float = 1.2) -> void:
	var effect : NeonEffect = _effects.get(channel) as NeonEffect
	if effect == null:
		effect = NeonEffect.new()
		effect.channel = channel
		effect.start_time = _time
		_effects[channel] = effect
	effect.color = color
	effect.pattern = pattern
	effect.priority = priority
	effect.period = maxf(period, 0.01)
	effect.expire_at = INF if hold_time < 0.0 else _time + hold_time
	_wake()


## Ends an effect immediately (cross-fades to the next active effect or idle)
func stop(channel : StringName) -> void:
	if _effects.erase(channel):
		_wake()


func stop_all() -> void:
	_effects.clear()
	_wake()



func start_beacon(target_global_position : Vector2) -> void:
	_beacon_target = target_global_position
	play(CHANNEL_BEACON, beacon_color, Pattern.BEACON, HOLD_UNTIL_STOP, PRIORITY_BEACON)


func set_beacon_target(target_global_position : Vector2) -> void:
	_beacon_target = target_global_position


## Call on each beacon beep: flashes the beacon neon in sync with the sound
func beacon_pulse() -> void:
	_beacon_last_pulse = _time


func stop_beacon() -> void:
	stop(CHANNEL_BEACON)


func is_beacon_active() -> bool:
	return _effects.has(CHANNEL_BEACON)


# --- Update ---------------------------------------------------------------------

func _process(delta : float) -> void:
	_time += delta
	if _debug_beacon_active:
		_beacon_target = get_global_mouse_position()
		if _time - _beacon_last_pulse >= debug_beacon_interval:
			beacon_pulse()
	var top_effect : NeonEffect = _update_effects()
	var top_channel : StringName = top_effect.channel if top_effect != null else &""
	if top_channel != _displayed_channel:
		# Displayed effect changed: cross-fade from the colors currently shown
		_displayed_channel = top_channel
		_start_transition()
	if _transition_progress < 1.0:
		_transition_progress = minf(_transition_progress + delta / maxf(transition_time, 0.001), 1.0)
	var eased_progress : float = smoothstep(0.0, 1.0, _transition_progress)
	var beacon_index : int = -1
	if top_effect != null and top_effect.pattern == Pattern.BEACON:
		beacon_index = _get_beacon_neon_index()
	for index : int in _neons.size():
		var target_color : Color = _compute_color(top_effect, index, beacon_index)
		_current_colors[index] = _from_colors[index].lerp(target_color, eased_progress)
		_neons[index].color = _current_colors[index]
	# Idle and settled: stop processing until the next call
	if top_effect == null and _transition_progress >= 1.0:
		set_process(false)
		if not idle_visible:
			hide()


## Removes expired effects and returns the one to display (null = idle)
func _update_effects() -> NeonEffect:
	var top_effect : NeonEffect = null
	for channel : StringName in _effects.keys():
		var effect : NeonEffect = _effects[channel]
		if effect.expire_at <= _time:
			_effects.erase(channel)
			continue
		if top_effect == null or effect.priority > top_effect.priority \
				or (effect.priority == top_effect.priority and effect.start_time > top_effect.start_time):
			top_effect = effect
	return top_effect


func _compute_color(effect : NeonEffect, index : int, beacon_index : int) -> Color:
	if effect == null:
		return _get_idle_color()
	var elapsed : float = _time - effect.start_time
	match effect.pattern:
		Pattern.PULSE:
			var pulse_factor : float = lerpf(pulse_min, 1.0, 0.5 - 0.5 * cos(TAU * elapsed / effect.period))
			return _scale_rgb(effect.color, pulse_factor)
		Pattern.BLINK:
			if fmod(elapsed, effect.period) < effect.period * 0.5:
				return effect.color
			return Color(0.0, 0.0, 0.0, 0.0)
		Pattern.RAINBOW:
			# Hue offset per neon: the rainbow turns around the car (follows the children order)
			var hue : float = fmod(elapsed / effect.period + float(index) / float(_neons.size()), 1.0)
			return Color.from_hsv(hue, 0.85, effect.color.v, effect.color.a)
		Pattern.BEACON:
			if index != beacon_index:
				return beacon_other_color
			# Flash on each beacon_pulse(), decaying back to beacon_min, boosted by beacon_intensity
			var flash : float = clampf(1.0 - (_time - _beacon_last_pulse) / maxf(beacon_flash_time, 0.001), 0.0, 1.0)
			return _scale_rgb(effect.color, lerpf(beacon_min, 1.0, flash) * beacon_intensity)
	return effect.color  # Pattern.STEADY


func _get_beacon_neon_index() -> int:
	# Neon whose direction from the body center best matches the objective direction
	var to_target : Vector2 = to_local(_beacon_target) - _body_center
	var best_index : int = -1
	var best_dot : float = -INF
	for index : int in _neon_directions.size():
		var dot_value : float = _neon_directions[index].dot(to_target)
		if dot_value > best_dot:
			best_dot = dot_value
			best_index = index
	return best_index


# --- Helpers ----------------------------------------------------------------------

func _compute_neon_directions() -> void:
	var centers : Array[Vector2] = []
	for neon : ColorRect in _neons:
		var center : Vector2 = neon.get_transform() * (neon.size * 0.5)
		centers.append(center)
		_body_center += center
	if _neons.is_empty():
		return
	_body_center /= float(_neons.size())
	for center : Vector2 in centers:
		_neon_directions.append((center - _body_center).normalized())


func _get_idle_color() -> Color:
	return idle_color if idle_visible else Color(0.0, 0.0, 0.0, 0.0)


func _scale_rgb(color : Color, factor : float) -> Color:
	# Scale RGB only: alpha stays the visibility factor
	return Color(color.r * factor, color.g * factor, color.b * factor, color.a)


func _start_transition() -> void:
	_from_colors = _current_colors.duplicate()
	_transition_progress = 0.0


func _wake() -> void:
	show()
	set_process(true)

func _on_blood_absorbed() -> void:
	play(CHANNEL_BLOOD, blood_color, Pattern.PULSE, blood_hold_time, PRIORITY_BLOOD)


#--------------------- DEBUG ---------------------

func _unhandled_input(event : InputEvent) -> void:
	if not GameMaster.is_debug():
		return
	var key_event : InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_N:
		_debug_next_neon()
		get_viewport().set_input_as_handled()


func _debug_next_neon() -> void:
	# Each debug effect uses its own channel so switching triggers the in-game cross-fade
	if _debug_channel != &"":
		stop(_debug_channel)
	_debug_beacon_active = false
	_debug_index = (_debug_index + 1) % DEBUG_NEON_NAMES.size()
	var neon_name : StringName = DEBUG_NEON_NAMES[_debug_index]
	_debug_channel = StringName("debug_" + String(neon_name))
	match neon_name:
		&"blood":
			play(_debug_channel, blood_color, Pattern.PULSE, HOLD_UNTIL_STOP, PRIORITY_DEBUG)
		&"dollars":
			play(_debug_channel, DEBUG_DOLLARS_COLOR, Pattern.PULSE, HOLD_UNTIL_STOP, PRIORITY_DEBUG)
		&"xp":
			play(_debug_channel, Color.WHITE, Pattern.RAINBOW, HOLD_UNTIL_STOP, PRIORITY_DEBUG, DEBUG_XP_PERIOD)
		&"beacon":
			_debug_beacon_active = true
			_beacon_target = get_global_mouse_position()
			play(_debug_channel, beacon_color, Pattern.BEACON, HOLD_UNTIL_STOP, PRIORITY_DEBUG)
		&"low_health":
			play(_debug_channel, Color.RED, Pattern.BLINK, HOLD_UNTIL_STOP, PRIORITY_DEBUG)
			
		_:
			# Idle: nothing to play, the neons fade back to idle
			_debug_channel = &""
	print("[Neons debug] ", neon_name)
