extends Area2D
class_name Enemy

var enemy : EnemyData

# MAIN STATS
@export_group("MAIN")
var speed: Statistic
var max_life: Statistic
var dmg: Statistic
var impact_force: Statistic
var knockback_friction: Statistic

@export var nb_xp: int = 1

var night_max_life_boost : float
var night_speed_boost: float
var night_damages_boost : float
var level_life_boost : int
var type : EnemyManager.Enemy_Types

@onready var current_life: int
var is_dead: bool = false
@export var leader: Enemy = null
var is_leader: bool = false
var horde: Array
var horde_neighbors: Array
var velocity: Vector2 = Vector2.ZERO
@onready var state_machine: Node = $StateMachine
@onready var player: Node2D = null

@onready var hordes_manager: HordeManager = $/root/World/HordesManager

@onready var damage_label_pool: DamageLabelPool = $/root/World/VFX/DamageLabelPool
@onready var blood_impact_pool: BloodImpactPool = $/root/World/VFX/BloodImpactPool
@onready var flow_field: FlowFieldManager = $"/root/World/FlowFieldManager"
#@export var obstacle_probe_margin: float = 12.0 #half size of the sprite

# MULTIMESH
@onready var renderer: EnemiesMultiMeshRenderer = $/root/World/EnemiesMMR2D
var mm_pool: EnemiesMultiMeshRenderer.EnemyTypePool = null # pool dédié au type de cet ennemi
var mm_index: int = -1 # -1 = not registered in mmr2D


# IMPACT ON PLAYER -------------------------------------- TO DO : transform in stats
var night_impact_force_boost : float = 4
var night_knockback_friction_boost : float = 4

@export_group("PHYSICS")
@export var chained_impacts_threshold: float = 200.0 #impact chained to neighbours impact speed higher than threshold
var knockback_velocity : Vector2 = Vector2.ZERO
var losing_strenght_ratio: float = 0.6 #of impact speed is transfered to neighbours
var night_losing_strenght_boost : float = 2
var side_impact_ratio: float = 0.3
var front_impact_ratio: float = -1.2
var last_move_dir := Vector2.RIGHT

@export var speed_variation: float = 10.0

@export_group("WALLS PHYSICS")
var near_wall : bool = false
@export var wall_test_distance: float = 24.0
@export var wall_collision_mask: int = 8

@export_group("DROPS SCENES")
@export var xp_scene: PackedScene
@export var dollar_scene: PackedScene

@export_group("UI")
@onready var damages_text_pos: Marker2D = get_node("MarkerDamages")
@onready var damage_timer: Timer = $DamageLabelTimer
@onready var damage_timer_on_player: Timer = $DamageTimer_OnPlayer
@onready var damage_flash_timer: Timer = $DamageFlashTimer
@onready var collision_box: CollisionShape2D = $CollisionShape2D
@onready var marker_damages: Marker2D = $MarkerDamages
@export var damages_label: PackedScene
#@export var blood_particles: PackedScene = null

# GAME
@onready var day_manager: Node = $/root/World/DayManager
var day_is_ended: bool = false
var game_paused := false
var game_over := false

@onready var bloody_engine: BloodyEngine = $/root/World/Car/BloodyEngine
@onready var blood_shot_pool: BloodShotPool = $/root/World/VFX/BloodShotPool

#PERFS STAGGER
var physics_skip_timer : float = 0
var physics_skip_steps : float = 0.032
var accumululated_delta : float

#NIGHT MODIFIERS
var night_speed_mod : Modifier
var night_dmg_mod : Modifier
var night_life_mod : Modifier
var enemy_freezer : Modifier


func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	ItemManager.freeze.connect(_on_freeze)
 
	init_stats()
 
	night_max_life_boost  = enemy.base_night_life_bonus
	night_speed_boost = enemy.base_night_speed_bonus
	night_damages_boost = enemy.base_night_dmg_bonus
	level_life_boost = enemy.level_life_boost
	type = enemy.type
 
	if RoadMapManager.steps_reached > 1:
		max_life.remove_modifier(EnemyManager.max_life_mod)
		max_life.add_modifier(EnemyManager.max_life_mod)
	elif RoadMapManager.steps_reached == 1:
		max_life.add_modifier(EnemyManager.max_life_mod)
 
	current_life = int(max_life.get_value())
 
	night_speed_mod = Modifier.new(night_speed_boost,Modifier.Type.PERCENT_MULT,"day_end_enemy_speed_mod")
	night_dmg_mod = Modifier.new(night_damages_boost,Modifier.Type.PERCENT_MULT,"day_end_enemy_dmg_mod")
	night_life_mod = Modifier.new(night_max_life_boost,Modifier.Type.FLAT,"day_end_enemy_life_mod")
	enemy_freezer = Modifier.new(-1, Modifier.Type.PERCENT_MULT,"enemy freezer item", 3)

	call_deferred("register_to_renderer")
 
func init_stats() -> void:
	speed = Statistic.new(enemy.base_speed)
	max_life = Statistic.new(enemy.base_max_life)
	dmg = Statistic.new(enemy.base_dmg)
	impact_force = Statistic.new(enemy.base_impact_force)
	knockback_friction = Statistic.new(enemy.base_knockback_friction)
 
	if enemy.speed_variation > 0.0:
		var variation := randf_range(-enemy.speed_variation, enemy.speed_variation)
		speed.add_modifier(Modifier.new(variation, Modifier.Type.FLAT, "speed variation"))
 
	SignalManager.emit_signal("enemy_stats_init", self)
 
func _process(delta: float) -> void:
	delta = minf(delta, 0.066)
	if game_paused:
		return
	if is_dead:
		if knockback_velocity.length_squared() > 1.0:
			velocity = knockback_velocity
			var dead_length: float = move_toward(knockback_velocity.length(), 0.0, knockback_friction.get_value() * delta)
			knockback_velocity = knockback_velocity.normalized() * dead_length
			update_move(delta)
		else:
			knockback_velocity = Vector2.ZERO
			velocity = Vector2.ZERO
		return

	if knockback_velocity.length_squared() > 100:
		velocity = knockback_velocity
		var knockback_length: float = move_toward(knockback_velocity.length(), 0.0, knockback_friction.get_value() * delta)
		knockback_velocity = knockback_velocity.normalized() * knockback_length

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
	last_move_dir = velocity.normalized()
	if velocity.length_squared() < 0.01:
		return
	var move : Vector2 = velocity * delta
 
	if move.x != 0.0 and flow_field.is_blocked_world(global_position + Vector2(move.x, 0.0)):
		move.x = 0.0
	if move.y != 0.0 and flow_field.is_blocked_world(global_position + Vector2(0.0, move.y)):
		move.y = 0.0
 
	global_position += move
 
func register_to_renderer() -> void:
	if renderer:
		mm_pool = renderer.get_pool(enemy)
		mm_index = mm_pool.register_enemy(self)
 
func get_impact(car_forward: Vector2, car_right: Vector2, player_speed_ratio: float, player_global_pos : Vector2) -> void:
	if car_right == Vector2.ZERO:
		knockback_velocity = car_forward.normalized() * impact_force.get_value() * player_speed_ratio
		return
 
	var impact_on_enemy: Vector2 = global_position - player_global_pos
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
 
	knockback_velocity = push_direction.normalized() * impact_force.get_value() * player_speed_ratio
  
func chained_impacts() -> void:
	if knockback_velocity.length_squared() < chained_impacts_threshold * chained_impacts_threshold:
		return
	for i in range(horde_neighbors.size()-1,-1,-1):
		if !is_instance_valid(horde_neighbors[i]):
			continue
		if global_position.distance_squared_to(horde_neighbors[i].global_position) < 900: #30px * 30px
			var push_dir: Vector2 = (horde_neighbors[i].global_position - global_position).normalized()
			var transferred_ratio: float = (knockback_velocity.length() / impact_force.get_value()) * losing_strenght_ratio
			horde_neighbors[i].get_impact(push_dir, Vector2.ZERO, transferred_ratio, global_position)
 
func get_damages(damages: int, hit_direction: Vector2 = Vector2.ZERO, knockback_force: float = 0.0) -> void:
	if game_paused or is_dead:
		return
	damage_timer.start()
	current_life -= damages
	flash_damage()
	display_damages(damages)
	apply_knockback(hit_direction, knockback_force)   # impact non létal
	if current_life <= 0:
		current_life = 0
		call_deferred("on_death", hit_direction, knockback_force * 2.0)
		return
	
	var shot_rotation: float = hit_direction.angle() if hit_direction != Vector2.ZERO else last_move_dir.angle()
	blood_shot_pool.shoot_blood(global_position, shot_rotation)

 
func get_damages_from_car(damages: int) -> void:
	if not game_paused:
		damage_timer.start()
		current_life -= damages
		flash_damage()
		display_damages(damages)
		if current_life <= 0:
			current_life = 0
			call_deferred("on_death")
			#call_deferred("fuel_up")
 
func flash_damage() -> void:
	if mm_pool == null or mm_index < 0:
		return
	mm_pool.set_enemy_flash(mm_index, true)
	damage_flash_timer.start()
 
func set_enemy_color(color: Color) -> void:
	if mm_pool == null or mm_index < 0:
		return
	mm_pool.set_enemy_color(mm_index, color)
 
func activate(spawn_position: Vector2) -> void:
	global_position = spawn_position
	current_life = int(max_life.get_value())
	show()
 
func _on_damage_timer_timeout() -> void:
	damage_timer.stop()
 
func _on_game_paused(game_on_pause: bool) -> void:
	game_paused = game_on_pause
 
#func fuel_up() -> void:
	#bloody_engine.bloody_vaccum()
	#bloody_engine.fuel_up(1)
 
func on_death(death_direction: Vector2 = Vector2.ZERO, death_force: float = 0.0) -> void:
	if is_dead:
		return
	is_dead = true

	#cut interractions
	collision_box.set_deferred("disabled", true)
	damage_timer_on_player.stop()
	damage_flash_timer.stop()
	if state_machine != null:
		state_machine.process_mode = Node.PROCESS_MODE_DISABLED
	if mm_pool != null and mm_index >= 0:
		mm_pool.set_enemy_flash(mm_index, false)

	# 2. drops
	var xp := xp_scene.instantiate()
	xp.xp_data = XPManager.xp_ressources[enemy.xp_type]
	get_node("/root/World/Collectables").add_child(xp)
	xp.launch_spawn(global_position)

	if enemy.drops_dollar:
		var dollar := dollar_scene.instantiate()
		get_node("/root/World/Collectables").add_child(dollar)
		dollar.launch_spawn(global_position)

	StatsManager.frags += 1
	SignalManager.emit_signal("enemy_is_dead", self, self.horde)

	set_process(true)
	process_mode = Node.PROCESS_MODE_INHERIT

	# 3. projection
	var push_direction: Vector2 = death_direction if death_direction != Vector2.ZERO else -last_move_dir
	var push_force: float = death_force if death_force > 0.0 else impact_force.get_value() * 0.5
	knockback_velocity = Vector2.ZERO
	apply_knockback(push_direction, push_force)

	# 4. blood vfx
	blow_up(global_position, - push_direction)

	# 5. dead sprites :
	set_animation_state("dead")
	if mm_pool == null or mm_index < 0:
		on_death_finished()

func on_death_finished() -> void:
	mm_index = -1
	mm_pool = null
	queue_free()

func on_coloss_death() -> void :
	#blow_up(global_position)
	collision_box.set_deferred("disabled", true)
 
	unregister_from_renderer()
 
	SignalManager.emit_signal("enemy_is_dead", self, self.horde)
  
func unregister_from_renderer() -> void:
	if mm_pool and mm_index >= 0:
		mm_pool.unregister_enemy(mm_index)
	mm_index = -1
	mm_pool = null
  
func _on_damage_timer_on_player_timeout() -> void:
	if player == null:
		return
	if "get_damages_from_mob" in player:
		player.get_damages_from_mob(dmg.get_value())
  
func display_damages(damages: int) -> void:
	var text_offset := Vector2(randf_range(-10.0, 10.0), randf_range(-50.0, 10.0))
	damage_label_pool.show_damages(damages, marker_damages.global_position + text_offset)
  
func blow_up(blood_position: Vector2, blood_direction : Vector2)-> void:
	var blood_rotation: float = (blood_direction if blood_direction != Vector2.ZERO else last_move_dir).angle()
	blood_impact_pool.splat_blood(blood_position, blood_rotation)

 
func set_animation_state(state_name: String) -> void:
	if mm_pool and mm_index >= 0:
		mm_pool.set_enemy_state(mm_index, state_name.to_lower())
  
func _on_hitbox_area_entered(area: Area2D) -> void:
	if !area.is_in_group("player"):
		return
	player = area.get_parent()
	if "get_damages_from_mob" in player:
		player.get_damages_from_mob(dmg.get_value())
	damage_timer_on_player.start()
  
func _on_hitbox_area_exited(area: Area2D) -> void:
	if !area.is_in_group("player"):
		return
	player = null
	damage_timer_on_player.stop()
 
func _on_damage_flash_timer_timeout() -> void:
	if mm_pool and mm_index >= 0:
		mm_pool.set_enemy_flash(mm_index, false)
	damage_flash_timer.stop()
 
func _on_freeze() -> void :
	speed.add_temp_modifier(enemy_freezer)
 
func get_enemy_stat(stat: EnemyData.Enemy_Stats) -> Statistic:
	match stat:
		EnemyData.Enemy_Stats.SPEED: return speed
		EnemyData.Enemy_Stats.MAX_LIFE: return max_life
		EnemyData.Enemy_Stats.DMG: return dmg
		EnemyData.Enemy_Stats.IMPACT_FORCE: return impact_force
		EnemyData.Enemy_Stats.KNOCKBACK_FRICTION: return knockback_friction
	return null

func apply_knockback(direction: Vector2, force: float) -> void:
	if direction == Vector2.ZERO or force <= 0.0:
		return
	knockback_velocity += direction.normalized() * force
