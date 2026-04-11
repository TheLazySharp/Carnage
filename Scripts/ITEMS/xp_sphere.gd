extends Area2D

var game_paused:=false

@export var xp_data : XPData

var velocity: Vector2
var target_pos: Vector2
var speed : = 500
var is_attracted := false
var xp_value : int

@onready var player: CharacterBody2D = $"/root/World/Car"


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	xp_value = TimeManager.current_day


func _physics_process(delta: float) -> void:
	if not game_paused and is_attracted:
		target_pos = player.global_position
		var dir : Vector2 = self.global_position.direction_to(target_pos)
		velocity = dir.normalized() * speed
		global_position += velocity * delta
	
	if abs(global_position - player.global_position).length() < 5:
		XPManager.add_xp_in_bucket(xp_value)
		#print("xp in bucket")
		queue_free()

		

func spawn(spawn_position : Vector2) -> void:
	global_position = spawn_position


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		is_attracted = true
		#print("is attracted")

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
