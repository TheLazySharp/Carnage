extends Node2D

@onready var car: CharacterBody2D = $".."

@onready var far_beeps: AudioStreamPlayer2D = $FarBeeps
@onready var close_beeps: AudioStreamPlayer2D = $CloseBeeps
@onready var beep_timer: Timer = $BeepTimer
@onready var survivors_spawner: Node2D = $/root/World/Spawners/Survivors

var beacon_pos : Vector2
var survivor_is_saved : bool = false
var close_far_threshold : float = 800
var beeps_steps : float = 200


func _ready() -> void:
	if survivors_spawner:
		survivors_spawner.beacon_activated.connect(_on_beacon_activated)
		SurvivorsManager.picked_up_survivor.connect(_on_survivor_picked_up)
		SignalManager.game_paused.connect(_on_game_paused)



func _process(_delta: float) -> void:
	if GameMaster.game_mode == GameMaster.GAME_MODES.GOD or GameMaster.game_mode == GameMaster.GAME_MODES.SANDBOX :
		far_beeps.stop()
		close_beeps.stop()
		return
	if RoadMapManager.last_district.type != DistrictsData.types.SURVIVOR or survivor_is_saved or !survivors_spawner:
		far_beeps.stop()
		close_beeps.stop()
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
		
	

func _on_beacon_activated(new_pos : Vector2) -> void:
	beacon_pos = new_pos
	
func get_distance_from_beacon()-> float:
	return car.global_position.distance_to(beacon_pos)
	
func _on_survivor_picked_up(_survivor : SurvivorData) -> void:
	survivor_is_saved = true
	far_beeps.stop()
	close_beeps.stop()


func _on_beep_timer_timeout() -> void:
	if GameMaster.game_mode == GameMaster.GAME_MODES.GOD or GameMaster.game_mode == GameMaster.GAME_MODES.SANDBOX :
		beep_timer.stop()
		return
	if RoadMapManager.last_district.type != DistrictsData.types.SURVIVOR or survivor_is_saved or !survivors_spawner:
		beep_timer.stop()
	if get_distance_from_beacon() > close_far_threshold:
		far_beeps.play()
	else : 
		close_beeps.play()
	
func _on_game_paused(game_paused : bool) -> void :
	if game_paused:
		close_beeps.stop()
		far_beeps.stop()
	else : 
		close_beeps.play()
		far_beeps.play()
	
