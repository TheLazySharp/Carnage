extends State
class_name EnemyIdle

@onready var enemy: Enemy = self.get_parent().get_parent()

var move_direction: Vector2
var wander_time : float
var move_speed: float
var speed_offset := 10


@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:=false

func _ready() -> void:
	gm_scene.game_paused.connect(_on_game_paused)

func enter()-> void:
	randomize_wander()


func exit()-> void:
	pass
	
func update(delta : float)-> void:
	if !game_paused:
		if wander_time > 0:
			wander_time -= delta
			
		else:
			randomize_wander()
	if enemy.is_from_the_horde:
		enemy.is_from_the_horde = false
		state_changed.emit(self,"horde")


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


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		#emit_signal("state_changed",self,"chase")
		state_changed.emit(self,"chase")
		#print("CHASE")
