extends State
class_name EnemyHorde

@onready var enemy: Enemy = self.get_parent().get_parent()

var move_direction: Vector2
var wander_time : float
var move_speed: float
var speed_offset := 10
@onready var detection_shape: CollisionShape2D = $"../../DetectionArea/DetectionShape"

@onready var day_manager: Node = $"/root/World/DayManager"
var is_day_ended:=false

@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:=false

func _ready() -> void:
	gm_scene.game_paused.connect(_on_game_paused)
	day_manager.day_ended.connect(_on_day_ended)

func enter()-> void:
	randomize_wander()
	detection_shape.set_deferred("disabled",true)
	

func exit()-> void:
	detection_shape.set_deferred("disabled",false)
	
func update(delta : float)-> void:
	if !game_paused:
		if wander_time > 0:
			wander_time -= delta
			
		else:
			randomize_wander()

func physics_update(_delta: float)-> void:
	if !game_paused:
		if enemy:
			enemy.velocity = move_direction * move_speed


func randomize_wander()-> void:
	move_direction = Vector2(randf_range(-1,1),randf_range(-1,1)).normalized()
	wander_time = randf_range(1,3)
	move_speed = randf_range((enemy.speed - speed_offset),(enemy.speed + speed_offset))

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause

func _on_day_ended(day_is_ended : bool) -> void:
	is_day_ended = day_is_ended
	if is_day_ended:
		state_changed.emit(self,"chase")
