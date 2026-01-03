extends Area2D

@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:=false

@export var xp_data : XPData

var velocity: Vector2
var target_pos: Vector2
var speed : = 500
var is_attracted := false
var xp_value

@onready var player: CharacterBody2D = $"/root/World/Car"


func _ready() -> void:
	gm_scene.game_paused.connect(_on_game_paused)
	xp_value = xp_data.xp_value

func _physics_process(delta: float) -> void:
	if not game_paused and is_attracted:
		target_pos = player.global_position
		var dir = self.global_position.direction_to(target_pos)
		velocity = dir.normalized() * speed
		global_position += velocity * delta
	
	if abs(global_position - player.global_position).length() < 5:
		XPManager.get_xp(xp_value)
		queue_free()
		

func spawn(spawn_position):
	global_position = spawn_position


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		is_attracted = true
		#print("is attracted")

func _on_game_paused(game_on_pause) -> void:
	game_paused = game_on_pause
