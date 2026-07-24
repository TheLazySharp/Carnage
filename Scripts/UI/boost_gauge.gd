extends ProgressBar


var game_paused:=false
@onready var boost_timer: Timer = $BoostTimer
var boost_can_load : bool = false
@onready var player : CharacterBody2D = $"/root/World/Car"

@onready var nitro: Label = $Nitro
@onready var dash: Label = $Dash
@onready var dash_anim: AnimationPlayer = $Dash/DashAnim


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	ItemManager.nitro_up.connect(_on_nitro_picked_up)
	player.dashing.connect(_on_player_dashing)
	value = 0
	nitro.show()
	dash.hide()

	

func _process(_delta: float) -> void:
	if CarManager.selected_car.drifting and !boost_can_load and value < CarManager.selected_car.max_boost_gauge:
		boost_can_load = true
		boost_timer.start()

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause


func _on_boost_timer_timeout() -> void:
	if value < CarManager.selected_car.max_boost_gauge :
		if CarManager.selected_car.drifting and !game_paused:
			value += CarManager.selected_car.nitro_up.get_value()
			nitro.show()
			dash.hide()
			
	else: 
		SignalManager.emit_signal("boost_gauge_is_full")
		nitro.hide()
		dash.show()
		dash_anim.play("boost_full")
		boost_can_load = false
		boost_timer.stop()


func _on_player_dashing() -> void:
	value = 0
	nitro.show()
	dash.hide()
	dash_anim.stop()

func _on_nitro_picked_up() -> void : 
	value = max_value
	boost_timer.start()
