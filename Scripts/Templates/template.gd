extends Node2D




var game_paused:=false


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
