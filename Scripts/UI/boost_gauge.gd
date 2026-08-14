extends ProgressBar


var game_paused : bool = false
@onready var boost_timer: Timer = $BoostTimer
var boost_can_load : bool = false
@onready var player : CharacterBody2D = $"/root/World/Car"

@onready var nitro: Label = $Nitro
@onready var dash: Label = $Dash
@onready var dash_anim: AnimationPlayer = $Dash/DashAnim

var car_data : CarData
var max_nitro : int = 0


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.nitro_changed.connect(_on_nitro_changed)
	ItemManager.nitro_up.connect(_on_nitro_picked_up)
	player.dashing.connect(_on_player_dashing)

	car_data = CarManager.selected_car
	max_nitro = int(car_data.max_nitro.get_value())
	max_value = max_nitro
	car_data.current_nitro = 0
	value = 0
	nitro.show()
	dash.hide()


func _process(_delta: float) -> void:
	if car_data.drifting and !boost_can_load and car_data.current_nitro < max_nitro:
		boost_can_load = true
		boost_timer.start()


func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause


func _on_boost_timer_timeout() -> void:
	if car_data.current_nitro >= max_nitro:
		boost_can_load = false
		boost_timer.stop()
		return

	if !car_data.drifting or game_paused:
		return

	car_data.current_nitro = mini(car_data.current_nitro + int(car_data.nitro_up.get_value()), max_nitro)
	refresh_display()

	if car_data.current_nitro >= max_nitro:
		SignalManager.boost_gauge_is_full.emit()
		boost_can_load = false
		boost_timer.stop()


func _on_nitro_changed(_current_nitro : int) -> void:
	refresh_display()


func _on_player_dashing() -> void:
	refresh_display()


func _on_nitro_picked_up(nitro_added : float) -> void:
	car_data.current_nitro += min(nitro_added, car_data.max_nitro.get_value() - car_data.current_nitro)
	refresh_display()
	SignalManager.boost_gauge_is_full.emit()
	boost_can_load = false
	boost_timer.stop()


func refresh_display() -> void:
	value = car_data.current_nitro

	var ready_to_dash : bool = car_data.current_nitro >= DashManager.MIN_NITRO_TO_START
	if ready_to_dash == dash.visible:
		return

	if ready_to_dash:
		nitro.hide()
		dash.show()
		dash_anim.play("boost_full")
	else:
		dash.hide()
		nitro.show()
		dash_anim.stop()
