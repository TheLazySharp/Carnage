extends Node

var game_paused : bool = false
var day_is_ended : bool = false
var game_is_over : bool = false

@onready var directional_light_2d: DirectionalLight2D = $"../DirectionalLight2D"

@onready var player: CharacterBody2D = null
#@onready var pause_manager: Control = $"../CanvasLayer/Pause"

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if !GameMaster.tutorial_active:
		player.game_over.connect(_update_game_over)
		TimeManager.load_time()
		ItemManager.load_pools()
	if ShopManager.all_car_boosts.is_empty():
		ShopManager.load_pools()
	


func _update_game_over(game_over : bool) -> void:
	game_is_over = game_over
	if game_is_over:
		SceneManager.load_level(SceneManager.SCENES.GAME_OVER)
