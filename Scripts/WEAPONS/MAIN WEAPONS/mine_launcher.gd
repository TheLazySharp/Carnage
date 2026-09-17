extends Node2D

const LANDMINE = preload("uid://b6sojfyjbslm1")

@export var launcher_data : WeaponData


var game_paused:=false
@onready var cool_down: Timer = $CoolDown
var cool_down_upgrade : float
@onready var car : CharacterBody2D = $"/root/World/Car"
@onready var mine_marker: Marker2D = $"/root/World/Car/MineMarker"
@onready var drop_mine_sfx: AudioStreamPlayer2D = $DropMineSfx

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)

	cool_down.wait_time = launcher_data.base_cool_down
	#max_lvl = launcher_data.max_level
	drop_mine_sfx.stream = launcher_data.weapon_sfx

	cool_down.wait_time = launcher_data.cool_down.get_value()
	launcher_data.cool_down.stat_adjusted.connect(_on_cool_down_modified)

func _process(_delta: float) -> void:
	if game_paused and !cool_down.paused:
		cool_down.paused = true
	
	if !game_paused and cool_down.paused:
		cool_down.paused = false 
	
	if !launcher_data.weapon_is_active:
		desactivate()

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause


func _on_cool_down_timeout() -> void:
	if !launcher_data.weapon_is_active: return
	drop_mine()

func drop_mine()-> void:
	for i in range(1,launcher_data.nb_projectile.get_value() + 1):
		var landmine : Node2D = LANDMINE.instantiate()
		get_node("/root/World/Explosives").add_child(landmine)
		landmine.global_position = mine_marker.global_position
		drop_mine_sfx.play()
		await get_tree().create_timer(0.2).timeout
	
func desactivate() -> void:
	cool_down.stop()

func _on_cool_down_modified(new_value : float) -> void : 
	cool_down.wait_time = new_value
