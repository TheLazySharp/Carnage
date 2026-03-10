extends Node2D

@onready var timer: Timer = $Timer

const ENEMY = preload("uid://c31g0smlywes2")

var max_enemy_count : int = 500
var nb_active_enemies : int = 0
@onready var game_manager: Node = $"/root/World/game_manager"
var game_paused:=false

@onready var zombies_q: Label = $"../../CanvasLayer/Board/Parts/MarginContainer/HBoxContainer/Zombies/ZombiesQ"

@export var auto_spawn:= true



func _ready() -> void:
	randomize()
	SignalManager.game_paused.connect(_on_game_paused)
	zombies_q.text = str(nb_active_enemies)

	
	
func _process(_delta: float) -> void:
	zombies_q.text = str(nb_active_enemies)
	
func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
	

func _on_timer_timeout() -> void:
	if not game_paused and auto_spawn and nb_active_enemies <= max_enemy_count:
		var r : int = RandomNumberGenerator.new().randi_range(0,self.get_child_count(false))
		for spawn_point in self.get_children():
			if spawn_point.name.to_int() == r and spawn_point.is_class("Marker2D"):
				if spawn_point.visible:
					print(r)
					var enemy : Enemy = create_enemies()
					enemy.activate(spawn_point.global_position)
					#print("enemy spawned on : ",spawn_point)
				else : print("spawn point visible on screen")



func create_enemies() -> Enemy:
	var enemy : Enemy = ENEMY.instantiate()
	get_node("/root/World/Enemies").add_child(enemy)
	return enemy

#COUNTER
func activated_enemies(n : int) -> int:
	nb_active_enemies += n
	#print(nb_active_enemies)
	return nb_active_enemies
	
