extends State
class_name EnemyChase

@onready var enemy: Enemy = $"../.."
@onready var target: Node2D = $"/root/World/Car"
@onready var flow_field: FlowFieldManager = $"/root/World/FlowFieldManager"

var chase_speed_boost: float = 1.6

var game_paused: bool =false
var game_over : bool = false

var seek_weight: float = 1.0

var repulsion_radius : float = 40
var repulsion_radius_sq : float

# STAGGER : on ne recalcule pas la direction à chaque tick SM
var update_timer: float = 0.0
var update_interval: float


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.game_is_over.connect(_on_game_over)
	repulsion_radius_sq = repulsion_radius * repulsion_radius
	update_interval = randf_range(0.18, 0.28)
	update_timer = randf_range(0.0, update_interval)

func enter() -> void:
	if game_over :
		state_changed.emit(self,"idle")
		return


func exit()-> void:
	pass

func physics_update(delta: float)-> void:
	if game_paused:
		return

	update_timer -= delta
	if update_timer > 0.0:
		return
	update_timer = update_interval


	var seek: Vector2 = flow_field.get_flow_direction(enemy.global_position) * seek_weight

	var separation: Vector2 = Vector2.ZERO
	for i in range(enemy.horde_neighbors.size() - 1, -1, -1):
		@warning_ignore("untyped_declaration")
		var other = enemy.horde_neighbors[i]
		if !is_instance_valid(other) or other == enemy:   # validité d'abord !
			continue
		var diff: Vector2 = enemy.global_position - other.global_position
		var dist_sq: float = diff.length_squared()
		if dist_sq < repulsion_radius_sq and dist_sq > 0.0001:
			separation += diff.normalized() * (repulsion_radius_sq / max(dist_sq, 1.0))

	var total: Vector2 = seek + separation
	if total.length_squared() > 0.0001:
		enemy.velocity = total.normalized() * enemy.speed.get_value() * chase_speed_boost
	else:
		enemy.velocity = Vector2.ZERO

func _on_game_over(game_is_over : bool)-> void : 
	game_over = game_is_over
	if game_is_over :
		state_changed.emit(self,"idle") 

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
