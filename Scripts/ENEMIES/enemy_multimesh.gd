extends Area2D
class_name Enemy

@export var max_life: int
var level_life_boost : int = 5
var night_max_life_boost : int = 3
@onready var current_life: int
var damages_on_player: float = 1
@export var speed: float
var nb_xp: int = 1
var is_leader: bool = false
@export var leader: Enemy = null
var horde: Array
var horde_neighbors: Array
var night_speed_boost: float = 2
var night_damages_boost : float = 2
var velocity: Vector2 = Vector2.ZERO
@onready var state_machine: Node = $StateMachine
@onready var player: Node2D = null

# MULTIMESH
@onready var renderer: EnemiesMultiMeshRenderer = $/root/World/EnemiesMMR2D
var mm_index: int = -1 # -1 = not registered in mmr2D

# IMPACT ON PLAYER
@export var impact_force: float = 300.0
var night_impact_force_boost : float = 4
@export var knockback_friction: float = 800.0
var night_knockback_friction_boost : float = 4
@export var chained_impacts_threshold: float = 200.0
var knockback_velocity := Vector2.ZERO
var losing_strenght_ratio: float = 0.6
var night_losing_strenght_boost : float = 2
var side_impact_ratio: float = 0.3
var front_impact_ratio: float = -1.2

@export var xp_scene: PackedScene

# UI
@onready var damages_text_pos: Marker2D = get_node("MarkerDamages")
@export var damages_label: PackedScene
@onready var damage_timer: Timer = $DamageLabelTimer
@onready var damage_timer_on_player: Timer = $DamageTimer_OnPlayer
@onready var damage_flash_timer: Timer = $DamageFlashTimer
@export var blood_particles: PackedScene = null
@onready var collision_box: CollisionShape2D = $CollisionShape2D
@onready var marker_damages: Marker2D = $MarkerDamages


# COLLISION WITH WALLS
var near_wall : bool = false
@export var wall_test_distance: float = 24.0
@export var wall_collision_mask: int = 8

# GAME
@onready var day_manager: Node = $/root/World/DayManager
var day_is_ended: bool = false
var game_paused := false
var game_over := false

#PERFS STAGGER
var physics_skip_timer : float = 0
var physics_skip_steps : float = 0.032
var accumululated_delta : float

#HORDE NEIGHBORS STAGGER
var neighbors_timer: float = 0.0
var neighbors_timer_steps: float = 0.5
var neighbors_detection_radius_sq : float = 400


func _ready() -> void:
	max_life += level_life_boost * (TimeManager.current_day - 1)
	current_life = max_life
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.day_time_end.connect(_on_day_end)
	call_deferred("register_to_renderer")
	#physics_skip_steps = randi() % 3



func _process(_delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if game_paused:
		return
	if knockback_velocity.length_squared() > 100:
		velocity = knockback_velocity
		var knockback_length: float = move_toward(knockback_velocity.length(), 0.0, knockback_friction * delta)
		knockback_velocity = knockback_velocity.normalized() * knockback_length

	#elif player:
		#velocity = (player.global_position - global_position).normalized() * speed
	
	neighbors_timer += delta
	if neighbors_timer >= neighbors_timer_steps :
		neighbors_timer = 0
		update_neighbors()
	
	accumululated_delta += delta
	physics_skip_timer += delta
	if physics_skip_timer < physics_skip_steps:
		return
	physics_skip_timer -= physics_skip_steps
	
	update_move(accumululated_delta)
	accumululated_delta = 0
	chained_impacts()




func update_move(delta: float) -> void:
	if velocity.length_squared() < 0.01:
		return
 
	var move : Vector2 = velocity * delta
 
#WALL DETECTION

	if !near_wall:
		global_position += move
		return
 
	var space := get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.new()
	params.collision_mask = wall_collision_mask
	params.exclude = [self]
 
	if abs(move.x) > 0.01:
		params.from = global_position
		params.to = global_position + Vector2(sign(move.x) * wall_test_distance, 0.0)
		if space.intersect_ray(params):
			move.x = 0.0
 
	if abs(move.y) > 0.01:
		params.from = global_position
		params.to = global_position + Vector2(0.0, sign(move.y) * wall_test_distance)
		if space.intersect_ray(params):
			move.y = 0.0
 
	global_position += move

func update_neighbors() -> void : 
	horde_neighbors.clear()
	for i in range(horde.size()-1,-1,-1) :
		if horde[i] == self or !is_instance_valid(horde[i]) :
			continue
		if global_position.distance_squared_to(horde[i].global_position) < neighbors_detection_radius_sq:
			horde_neighbors.append(horde[i])
		

func register_to_renderer() -> void:
	if renderer:
		mm_index = renderer.register_enemy(self)



func get_impact(car_forward: Vector2, car_right: Vector2, player_speed_ratio: float) -> void:
	if car_right == Vector2.ZERO:
		knockback_velocity = car_forward.normalized() * impact_force * player_speed_ratio
		return

	var impact_on_enemy: Vector2 = global_position - get_tree().get_first_node_in_group("player").global_position
	var lateral_dot: float = impact_on_enemy.dot(car_right)
	var forward_dot: float = impact_on_enemy.dot(car_forward)
	var impact_is_frontal: bool = abs(lateral_dot) < 30 and forward_dot > 0

	var push_direction: Vector2
	if impact_is_frontal:
		var random_side_push: float = 1.0 if randf() > 0.5 else -1.0
		push_direction = car_right * random_side_push * side_impact_ratio + car_forward * (front_impact_ratio)
	else:
		var side: int = sign(lateral_dot)
		push_direction = car_right * side + car_forward * side_impact_ratio

	knockback_velocity = push_direction.normalized() * impact_force * player_speed_ratio


func chained_impacts() -> void:
	if knockback_velocity.length_squared() < chained_impacts_threshold * chained_impacts_threshold:
		return
	for i in range(horde_neighbors.size()-1,-1,-1):
		if !is_instance_valid(horde_neighbors[i]):
			continue
		if global_position.distance_squared_to(horde_neighbors[i].global_position) < 900: #30px * 30px
			var push_dir: Vector2 = (horde_neighbors[i].global_position - global_position).normalized()
			var transferred_ratio: float = (knockback_velocity.length() / impact_force) * losing_strenght_ratio
			horde_neighbors[i].get_impact(push_dir, Vector2.ZERO, transferred_ratio)


func get_damages(damages: int) -> void:
	if not game_paused:
		damage_timer.start()
		current_life -= damages
		flash_damage()
		display_damages(damages)
		#blow_up(global_position)
		if current_life <= 0:
			current_life = 0
			call_deferred("on_death")


func flash_damage() -> void:
	if renderer == null or mm_index < 0:
		return
	renderer.set_enemy_flash(mm_index, true)
	damage_flash_timer.start()


func set_enemy_color(color: Color) -> void:
	if renderer == null or mm_index < 0:
		return
	renderer.set_enemy_color(mm_index, color)


func activate(spawn_position: Vector2) -> void:
	global_position = spawn_position
	current_life = max_life


func _on_damage_timer_timeout() -> void:
	damage_timer.stop()

func _on_game_paused(game_on_pause: bool) -> void:
	game_paused = game_on_pause


func on_death() -> void:
	if nb_xp == 1:
		blow_up(global_position)
		collision_box.set_deferred("disabled", true)
		nb_xp = 0

		var xp := xp_scene.instantiate()
		get_parent().add_child(xp)
		xp.spawn(global_position)

		StatsManager.frags += 1

		if renderer and mm_index >= 0:
			renderer.unregister_enemy(mm_index)
			mm_index = -1

		SignalManager.emit_signal("enemy_is_dead", self, self.horde)


func _on_damage_timer_on_player_timeout() -> void:
	if player == null:
		return
	if "get_damages_from_mob" in player:
		player.get_damages_from_mob(damages_on_player)


func display_damages(damages: int) -> void:
	var text_offsetX: float = randf_range(-10.0, 10.0)
	var text_offsetY: float = randf_range(-50.0, 10.0)
	var new_damages_label : Label = damages_label.instantiate()
	add_child(new_damages_label)
	new_damages_label.text =  str(damages)
	new_damages_label.global_position = Vector2(marker_damages.global_position.x + text_offsetX,marker_damages.global_position.y + text_offsetY)
	



func blow_up(blood_position: Vector2) -> void:
	if blood_particles:
		var blood: CPUParticles2D = blood_particles.instantiate()
		get_node("/root/World/VFX").add_child(blood)
		blood.global_position = blood_position


func _on_day_end(_day_end: bool) -> void:
	speed *= night_speed_boost
	damages_on_player *= night_damages_boost
	impact_force /= night_impact_force_boost
	knockback_friction /= night_knockback_friction_boost
	max_life *= night_max_life_boost


func set_animation_state(state_name: String) -> void:
	if renderer and mm_index >= 0:
		renderer.set_enemy_state(mm_index, state_name.to_lower())


func _on_hitbox_area_entered(area: Area2D) -> void:
	if !area.is_in_group("player"):
		return
	player = area.get_parent()
	if "get_damages_from_mob" in player:
		player.get_damages_from_mob(damages_on_player)
	damage_timer_on_player.start()


func _on_hitbox_area_exited(area: Area2D) -> void:
	if !area.is_in_group("player"):
		return
	player = null
	damage_timer_on_player.stop()


func _on_damage_flash_timer_timeout() -> void:
	if renderer and mm_index >= 0:
		renderer.set_enemy_flash(mm_index, false)
	damage_flash_timer.stop()
