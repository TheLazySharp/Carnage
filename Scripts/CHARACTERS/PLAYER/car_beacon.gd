extends Node2D

@onready var car: CharacterBody2D = $".."
@onready var car_neons : CarNeons = get_tree().get_first_node_in_group(&"car_neons") as CarNeons
@onready var far_beeps: AudioStreamPlayer2D = $FarBeeps
@onready var close_beeps: AudioStreamPlayer2D = $CloseBeeps
@onready var beep_timer: Timer = $BeepTimer
@onready var survivors_spawner: Node2D

var beacon_pos : Vector2 = Vector2.ZERO
var survivor_is_saved : bool = false
var close_far_threshold : float = 800
var beeps_steps : float = 200
var beacon_activated : bool = false
var mission_completed : bool = false

func _ready() -> void:
	if GameMaster.is_debug():
		return
	SignalManager.beacon_initiated.connect(_on_beacon_initiated)
	SignalManager.beacon_stop.connect(stop_beacon)
	SignalManager.beacon_start.connect(activate_beacon)
	SignalManager.mission_completed.connect(_on_mission_completed)
	

func _input(event: InputEvent) -> void:
	if mission_completed:
		return
	if event.is_action_pressed("activate_beacon") and !GameMaster.is_debug():
		if beacon_activated:
			stop_beacon()
		else:
			if !beacon_activated:
				activate_beacon()
		


func _process(_delta: float) -> void:
	if mission_completed:
		return
	if GameMaster.is_debug() or GameMaster.game_mode == GameMaster.GAME_MODES.GOD or GameMaster.game_mode == GameMaster.GAME_MODES.SANDBOX or !beacon_activated:
		return
	if get_distance_from_beacon() > 2000:
		beep_timer.wait_time = 2
	elif get_distance_from_beacon() <= 2000 and get_distance_from_beacon() > 1500:
		beep_timer.wait_time = 1.5
	elif get_distance_from_beacon() <= 1500 and get_distance_from_beacon() > 1000: 
		beep_timer.wait_time = 1.0
	elif get_distance_from_beacon() <= 1000 and get_distance_from_beacon() > 800: 
		beep_timer.wait_time = 0.8
	elif get_distance_from_beacon() <= 800 and get_distance_from_beacon() > 600: 
		beep_timer.wait_time = 0.6
	elif get_distance_from_beacon() <= 600 and get_distance_from_beacon() > 400: 
		beep_timer.wait_time = 0.4
	elif get_distance_from_beacon() <= 400 and get_distance_from_beacon() > 200: 
		beep_timer.wait_time = 0.2
	elif get_distance_from_beacon() <= 200:
		beep_timer.wait_time = 0.1


func _on_beacon_initiated(new_pos : Vector2) -> void:
	if mission_completed:
		return
	beacon_pos = new_pos
	

func get_distance_from_beacon()-> float:
	return car.global_position.distance_to(beacon_pos)
	

func _on_beep_timer_timeout() -> void:
	if mission_completed:
		return
	if GameMaster.is_debug() or GameMaster.game_mode == GameMaster.GAME_MODES.GOD or GameMaster.game_mode == GameMaster.GAME_MODES.SANDBOX or !beacon_activated:
		return
	if get_distance_from_beacon() > close_far_threshold:
		far_beeps.play()
		car_neons.beacon_pulse()
	else : 
		close_beeps.play()
		car_neons.beacon_pulse()
		
	
func _on_game_paused(game_paused : bool) -> void :
	if mission_completed:
		return
	if game_paused:
		close_beeps.stop()
		far_beeps.stop()
	else : 
		close_beeps.play()
		far_beeps.play()

func activate_beacon() -> void :
	if mission_completed:
		return
	if beacon_pos == Vector2.ZERO or beacon_activated:
		return
	beacon_activated = true
	close_beeps.play()
	far_beeps.play()
	car_neons.start_beacon(beacon_pos)


func stop_beacon() -> void : 
	if mission_completed:
		return
	if !beacon_activated:
		return
	beacon_activated = false
	close_beeps.stop()
	far_beeps.stop()
	if car_neons.is_beacon_active():
		car_neons.stop_beacon()

func _on_mission_completed() -> void:
	mission_completed = true
