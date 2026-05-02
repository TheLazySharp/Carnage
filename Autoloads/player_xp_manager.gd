extends Node

var xp_levels: Array
var current_level: int
var current_xp: int
var current_level_target_xp: int
var total_levels:int = 100

var available_upgrades:= 0
var total_upgrades:=0
var upgrade_cost: int
var x: int

var animation:= false
signal update_xp(current_xp: int)
signal update_max_xp_target(target_xp: int)
signal animation_play(animation_ok : bool)
signal update_level(current_level: int)
signal level_up_sfx

var xp_bucket: Array
var is_processing : bool = false
var xp_delay : float = 0.05

var game_paused:=false

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	for i in (total_levels+1):
		#xp_levels.append(roundi( (4 * (i**2) ) * 0.2 )+3)
		@warning_ignore("integer_division")
		xp_levels.append(roundi((i/0.08)**2)/30)
	current_level = 1

	current_level_target_xp = xp_levels[current_level]
	current_xp = 0

	emit_signal("update_xp", current_xp)
	emit_signal("update_max_xp_target", current_level_target_xp)
	emit_signal("update_level",current_level)
	
	#total_upgrades = 1
	x = roundi(((total_upgrades + 81)-92)*0.02)
	upgrade_cost = roundi(((x + 0.1)*((total_upgrades+81)**2))+1)
	cost_formula(0)
	
	
func _process(_delta: float) -> void:
	pass
	#if !game_paused:
		#if current_xp >= current_level_target_xp and !leveling_up:
			#level_up()
		#get_xp()


func update_upgrades()-> void : 
	available_upgrades = current_level - total_upgrades - 1
	x = roundi(((total_upgrades + 81)-92)*0.02)
	upgrade_cost = roundi(((x + 0.1)*((total_upgrades+81)**2))+1)
	cost_formula(0)
	
func add_xp_in_bucket(xp_value : int)-> void:
	xp_bucket.append(xp_value)
	if !is_processing:
		process_next_xp()
	
func process_next_xp() -> void : 
	if game_paused or xp_bucket.is_empty():
		is_processing = false
		return
	
	is_processing = true
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


#func get_xp() -> void:
	#if !game_paused and !xp_bucket.is_empty():
		##print("bucke size : ",xp_bucket.size())
		#for i in range(xp_bucket.size()-1,-1,-1):
			#if current_level_target_xp - current_xp >= xp_bucket[i] :
				#current_xp += xp_bucket[i]
				#emit_signal("update_xp", current_xp)
				#xp_bucket.remove_at(i)
				#break
			#if current_level_target_xp - current_xp < xp_bucket[i] :
				#var xp_needed : int = current_level_target_xp - current_xp
				#var xp_exceed : int = xp_bucket[i] - xp_needed
				#current_xp += xp_needed
				#emit_signal("update_xp", current_xp)
				#xp_bucket.remove_at(i)
				#if xp_exceed > 0:
					#xp_bucket.append(xp_exceed)



func level_up() -> void:
	emit_signal("level_up_sfx")
	current_level += 1
	StatsManager.update_car_stats(CarManager.selected_car)
	current_level_target_xp = xp_levels[current_level]
	current_xp -= xp_levels[current_level-1]

	emit_signal("update_level",current_level)
	emit_signal("animation_play", true)
	emit_signal("update_xp", current_xp)
	emit_signal("update_max_xp_target", current_level_target_xp)

func unload() -> void:
	current_level = 1
	current_level_target_xp = xp_levels[current_level]
	current_xp = 0
	xp_bucket.clear()
	
	emit_signal("update_xp", current_xp)
	emit_signal("update_max_xp_target", current_level_target_xp)
	emit_signal("update_level",current_level)

	#print("xp manager unload")
	
func cost_formula(i : int) -> int:
	x = roundi(((total_upgrades + i + 81)-92)*0.02)
	upgrade_cost = roundi(((x + 0.1)*((total_upgrades + i + 81)**2))+1)
	return upgrade_cost

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
