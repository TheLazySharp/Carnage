extends Node2D

var car_res : CarData
@onready var car_node: CharacterBody2D = $"../.."
var rpm_loops : Array =[1000, 2000,3000,4000,5000]

const GEARS := [
	{"min_spd":   0.0, "max_spd":  80.0, "min_rpm": 1000.0, "max_rpm": 5000.0},
	{"min_spd":  80.0, "max_spd": 160.0, "min_rpm": 1000.0, "max_rpm": 5000.0},
	{"min_spd": 160.0, "max_spd": 240.0, "min_rpm": 1000.0, "max_rpm": 5000.0},
	{"min_spd": 240.0, "max_spd": 320.0, "min_rpm": 1000.0, "max_rpm": 5000.0},
]

var current_gear_index : int
var gear_margin : float = 0.1
var last_speed : float = 0.0
var speed_drop_threshold : float = 10
var burnout_rpm : float = 1000
var burn_timer : float = 0
var revving_speed : float = 40
var loop_players : Array = []
var smoothed_rpm : float = 1000
var rpm_step : float = 1000

var max_speed : float
var fade_time_up : float = 1.5
var fade_time_down : float = 0.05

var game_over : bool = false

func _ready() -> void:
	car_res = CarManager.selected_car
	car_node.dashing.connect(on_dash)
	SignalManager.game_is_over.connect(_on_game_over)
	max_speed = car_res.max_speed.get_value()
	
	for i in rpm_loops.size():
		var player := AudioStreamPlayer.new()
		player.stream = load("res://Assets/Audio/SFX/Car/Engine/RPM_%d.mp3" % rpm_loops[i])
		player.bus = "Engine"
		player.stream.loop = true
		player.volume_db = -80
		add_child(player)
		player.play()
		loop_players.append(player)

func get_rpm_from_speed(speed: float, is_burning : bool) -> float:
	if is_burning:
		burn_timer += get_process_delta_time()
		burnout_rpm = 4500 + sin(burn_timer * revving_speed) * 500
		last_speed = speed
		return burnout_rpm
	else : 
		burn_timer = 0
	
	if speed < 5.0:
		current_gear_index = 0
		last_speed = speed
		return 1000
	
	if last_speed - speed > speed_drop_threshold:
		current_gear_index = 0
		for i in range(GEARS.size()-1,-1,-1):
			if speed >= GEARS[i].min_spd:
				current_gear_index = i
				break

	current_gear_index = clampi(current_gear_index,0,GEARS.size() - 1)
	last_speed = speed
	
	var gear : Dictionary = GEARS[current_gear_index]
	var t : float = clampf((speed - gear.min_spd) / (gear.max_spd - gear.min_spd), 0.0, 1.0)
	return lerp(gear.min_rpm, gear.max_rpm, t)
	
	
func get_gear_idx(speed: float) -> int:
	var accelerating : bool = speed> last_speed
	
	if accelerating:
		if current_gear_index < GEARS.size() - 1:
			if speed >= GEARS[current_gear_index].max_spd:
				return current_gear_index + 1
		return current_gear_index + 1
	else:
		for i in range(GEARS.size()-1,-1,-1):
			if speed >= GEARS[i].min_spd:
				return 1
		return 0


func update_engine_sfx(current_speed : float, is_burning : bool) -> void : 
	var target_rpm : float = get_rpm_from_speed(current_speed,is_burning)
	var fade := fade_time_up if target_rpm > smoothed_rpm else fade_time_down
	if is_burning:
		smoothed_rpm = target_rpm
	
	else :
		smoothed_rpm = lerp(smoothed_rpm, target_rpm,1.0 - exp(-get_process_delta_time() / fade))
	
	var best_index := 0
	var best_dist  := INF
	for i in range(rpm_loops.size()):
		var dist := absf(smoothed_rpm - float(rpm_loops[i]))
		if dist < best_dist:
			best_dist = dist
			best_index = i

	#print("gear:%d | speed:%.0f | rpm:%.0f | pitch:%.2f" % [best_index + 1,current_speed,smoothed_rpm,smoothed_rpm / float(rpm_loops[best_index])], "/ is burning:",is_burning)

	for i in range(loop_players.size()):
		if i == best_index:
			loop_players[i].volume_db = 0.0
			loop_players[i].pitch_scale = smoothed_rpm / float(rpm_loops[i])
		else:
			loop_players[i].volume_db = lerp(loop_players[i].volume_db, -80.0,
			1.0 - exp(-get_process_delta_time() / fade))

func on_dash()-> void : 
	smoothed_rpm = 4000
	current_gear_index = clampi(get_gear_idx(last_speed),0,GEARS.size() - 1)

func _on_game_over(game_is_over : bool) -> void : 
	game_over = game_is_over
	for i in range(loop_players.size()):
		loop_players[i].volume_db = -80
	print("game is over on sfx : ",game_over)
