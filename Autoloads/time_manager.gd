extends Node

var current_day: int = 0
var total_day: int = 3
var current_night: int
var total_night:int = 3
var day_lenght: int

var active_time : float
var tracking_time : bool = false

func _ready() -> void:
	active_time = 0.0
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.next_day.connect(_on_raid_end)
	SignalManager.game_is_over.connect(_on_game_over)
	SignalManager.start_timer.connect(_on_timer_start)

func unload() -> void : 
	current_day = 0

func _process(delta: float) -> void:
	if tracking_time:
		active_time += delta

func _on_game_paused(game_paused : bool) -> void:
	tracking_time = !game_paused
	
func _on_raid_end() -> void : 
	tracking_time = false
	
func _on_game_over(_game_is_over : bool) -> void : 
	tracking_time = false

func _on_timer_start() -> void : 
	tracking_time = true

func load_time() -> void : 
	day_lenght = 60 if GameMaster.game_mode == GameMaster.GAME_MODES.GOD else 60
	
