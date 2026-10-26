extends Node

var xp_levels: Array
var current_level: int
var current_xp: int
var current_level_target_xp: int
var total_levels:int = 100

var available_upgrades : int  = 0
var total_upgrades : int = 0
var upgrade_cost : int
var x : int

var animation :  bool = false
signal update_xp(current_xp: int)
signal update_max_xp_target(target_xp: int)
signal animation_play(animation_ok : bool)
signal update_level(current_level: int)
signal level_up_sfx

var xp_bucket: Array
var is_leveling : bool = false
var xp_delay : float = 0.05

var game_paused : bool = false

var raid_xp : int = 0  # DEBUG: XP gained in the current raid (curve tuning)

## XP needed to go from level L to L+1 = LEVEL_COST_SCALE * (L + LEVEL_COST_OFFSET) ^ LEVEL_COST_EXPONENT
const LEVEL_COST_SCALE : float = 8.0
const LEVEL_COST_OFFSET : int = 3
const LEVEL_COST_EXPONENT : float = 2.0

enum XP_TYPES {
	XP_1,
	XP_2,
	XP_5,
	XP_10
}

const XP_SPHERE_1 = preload("uid://b1rnp8w8r7smq")
#const XP_SPHERE_2 = preload("uid://fxr6ftyl6c2j")
#const XP_SPHERE_5 = preload("uid://bvo82cae7qnoy")

var xp_ressources : Dictionary  = {
	XP_TYPES.XP_1 : XP_SPHERE_1,
	#XP_TYPES.XP_2 : XP_SPHERE_2,
	#XP_TYPES.XP_5 : XP_SPHERE_5
	}


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.next_day.connect(_on_raid_ended)
	
	for i in (total_levels + 1):
		xp_levels.append(_level_cost(i))
	current_level = 1

	current_level_target_xp = xp_levels[current_level]
	current_xp = 0

	emit_signal("update_xp", current_xp)
	emit_signal("update_max_xp_target", current_level_target_xp)
	emit_signal("update_level",current_level)
	

func _level_cost(level : int) -> int:
	return roundi(LEVEL_COST_SCALE * pow(float(level + LEVEL_COST_OFFSET), LEVEL_COST_EXPONENT))
	
	
func add_xp_in_bucket(xp_value : int)-> void:
	xp_bucket.append(xp_value)
	raid_xp += xp_value
	if !is_leveling:
		process_next_xp()
	
func process_next_xp() -> void : 
	if game_paused or xp_bucket.is_empty():
		is_leveling = false
		return
	
	is_leveling = true
	var xp_value: int = xp_bucket.pop_front()
	var xp_needed: int = current_level_target_xp - current_xp

	if xp_value <= xp_needed:
		current_xp += xp_value
	else:
		current_xp += xp_needed
		xp_bucket.push_front(xp_value - xp_needed)

	emit_signal("update_xp", current_xp)

	if current_xp >= current_level_target_xp:
		level_up()
	
	await get_tree().create_timer(xp_delay).timeout
	process_next_xp()


func level_up() -> void:
	emit_signal("level_up_sfx")
	current_level += 1
	current_level_target_xp = xp_levels[current_level]
	current_xp -= xp_levels[current_level-1]

	emit_signal("update_level",current_level)
	emit_signal("animation_play", true)
	emit_signal("update_xp", current_xp)
	emit_signal("update_max_xp_target", current_level_target_xp)
	
	available_upgrades += 1

func unload() -> void:
	current_level = 1
	current_level_target_xp = xp_levels[current_level]
	current_xp = 0
	xp_bucket.clear()
	
	emit_signal("update_xp", current_xp)
	emit_signal("update_max_xp_target", current_level_target_xp)
	emit_signal("update_level",current_level)

	available_upgrades = 0
	
## DEBUG: XP of the raid that just ended, to tune LEVEL_BASE_COST / LEVEL_COST_GROWTH
func _on_raid_ended() -> void:
	print("[XP] raid xp : ", raid_xp, " | level : ", current_level, " | upgrades waiting : ", available_upgrades)
	raid_xp = 0

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
