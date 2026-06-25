extends Node2D
class_name BloodyEngine

var player : CarData
var game_paused:=false
@onready var car: CharacterBody2D = $".."

#FUEL
@onready var fuel_bar: ProgressBar = $"/root/World/CanvasLayer/HUD/FuelGauge"
@onready var fuel_label: Label = $"/root/World/CanvasLayer/HUD/FuelGauge/FuelLabel"
var max_fuel : float


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	car.dash_end.connect(_on_dash_end)


func init_bloody_engine(p_player : CarData) -> void : 
	player = p_player
	max_fuel = player.max_fuel.get_value()
	player.current_fuel = int(max_fuel)
	fuel_bar.max_value = max_fuel
	fuel_bar.value = player.max_fuel.get_value()

func _process(_delta: float) -> void:
	fuel_label.text = str(player.current_fuel) + "/" + str(int(player.max_fuel.get_value()))

func _on_game_paused(game_on_pause :bool) -> void:
	game_paused = game_on_pause

func _on_dash_end() -> void : 
	player.current_fuel -= player.dash_fuel_down
	fuel_bar.value = player.current_fuel

func fuel_up(added_fuel : int) -> void : 
	player.current_fuel += added_fuel
	if player.current_fuel > player.max_fuel.get_value() :
		player.current_fuel = int(player.max_fuel.get_value())
	fuel_bar.value = player.current_fuel
