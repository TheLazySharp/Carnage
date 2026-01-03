extends Node2D



@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:=false


func _ready() -> void:
	gm_scene.game_paused.connect(_on_game_paused)

func _on_game_paused(game_on_pause) -> void:
	game_paused = game_on_pause
