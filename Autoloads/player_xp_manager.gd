extends Node

var xp_levels: Array
var current_level: int
var current_xp: int
var current_level_target_xp: int
var total_levels:int = 50

var animation:= false


signal update_xp(current_xp: int)
signal update_max_xp_target(target_xp: int)
signal animation_play(animation_ok : bool)
signal update_level(current_level: int)

func _ready() -> void:
	for i in (total_levels+1):
		@warning_ignore("integer_division")
		xp_levels.append(round( (4 * (i**2) ) * 0.2 )+3)
	current_level = 1

	current_level_target_xp = xp_levels[current_level]
	current_xp = 0

	emit_signal("update_xp", current_xp)
	emit_signal("update_max_xp_target", current_level_target_xp)
	emit_signal("update_level",current_level)
	
	
func _process(_delta: float) -> void:
	if current_xp >= current_level_target_xp:
		level_up()

func get_xp(xp) -> void:
	current_xp += xp
	emit_signal("update_xp", current_xp)
	

func level_up() -> void:

	current_level += 1
	current_level_target_xp = xp_levels[current_level]
	current_xp -= xp_levels[current_level-1]

	emit_signal("update_level",current_level)
	animation = true
	emit_signal("animation_play", animation)
	
	await get_tree().create_timer(0.8).timeout
	emit_signal("update_xp", current_xp)
	emit_signal("update_max_xp_target", current_level_target_xp)

func unload() -> void:
	current_level = 1
	current_level_target_xp = xp_levels[current_level]
	current_xp = 0
	
	emit_signal("update_xp", current_xp)
	emit_signal("update_max_xp_target", current_level_target_xp)
	emit_signal("update_level",current_level)
