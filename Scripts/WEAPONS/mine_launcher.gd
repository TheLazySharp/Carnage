extends Node2D

const LANDMINE = preload("uid://b6sojfyjbslm1")

@export var launcher_data : WeaponData

var current_lvl: int
var max_lvl : int

@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:=false
@onready var cool_down: Timer = $CoolDown
@onready var mine_marker: Marker2D = $"/root/World/Car/MineMarker"

func _ready() -> void:
	gm_scene.game_paused.connect(_on_game_paused)
	cool_down.wait_time = launcher_data.cool_down
	max_lvl = launcher_data.max_level


func _process(_delta: float) -> void:
	current_lvl = clampi(launcher_data.current_level,0,max_lvl)
	cool_down.wait_time = launcher_data.cool_down - current_lvl * 0.1
	
	if game_paused and !cool_down.paused:
		cool_down.paused = true
	
	if !game_paused and cool_down.paused:
		cool_down.paused = false 
	

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause


func _on_cool_down_timeout() -> void:
	drop_mine(mine_marker.global_position)

func drop_mine(drop_pos: Vector2)-> void:
	var landmine : Node2D = LANDMINE.instantiate()
	get_node("/root/World/Explosives").add_child(landmine)
	landmine.global_position = drop_pos
	
	
