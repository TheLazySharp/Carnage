extends State
class_name EnemyAttack

@onready var enemy: Enemy = self.get_parent().get_parent()
@onready var target : CharacterBody2D = $"/root/World/Car"
var move_direction: Vector2
var move_speed: float

var game_paused:=false

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.game_is_over.connect(_on_game_over)


func enter()-> void:
	pass


func exit()-> void:
	pass
	
func update(_delta : float)-> void:
	if !game_paused:
		#enemy.sprite_update(target.global_position)
		if enemy.global_position.distance_to(target.global_position) <  5:
			move_speed = 10
			move_direction = target.global_position - enemy.global_position
		else : state_changed.emit(self,"chase")


func physics_update(_delta: float)-> void:
	if !game_paused:
		if enemy:
			enemy.velocity = move_direction * move_speed


func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause

func _on_game_over(game_is_over : bool)-> void : 
	if game_is_over :
		state_changed.emit(self,"idle") 
