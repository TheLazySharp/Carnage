extends CharacterBody2D
class_name Enemy

@export var max_life: int = 10
@onready var current_life: int
var damages_on_player: float = 1
var speed: float = 40
var nb_xp: int =1
var is_leader: bool = false
@export var leader: Enemy = null
var horde : Array
var horde_neighbors : Array
var night_speed_boost : float = 1.5
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: Node = $StateMachine
@onready var player: Node2D = null



#IMPACT ON PLAYER
@export var impact_force : float = 200.0
@export var knockback_friction : float = 300.0
@export var chained_impacts_threshold :float = 200.0
var knockback_velocity : = Vector2.ZERO
var losing_strenght_ratio : float = 0.6
var side_impact_ratio : float = 0.3
var front_impact_ratio : float = -1.2
@export var xp_scene: PackedScene

#UI
@onready var damages_text_pos : Marker2D = get_node("MarkerDamages")
@export var damages_text: PackedScene
#@onready var color_rect = get_node("ColorRect")
@onready var damage_timer: Timer = $DamageTimer_Get
@onready var base_color: Color
@onready var damage_timer_on_player: Timer = $DamageTimer_OnPlayer
@export var blood_particles : PackedScene = null


@onready var collision_box: CollisionShape2D = $CollisionShape2D


#GAME
@onready var day_manager: Node = $/root/World/DayManager
var day_is_ended : bool = false
var game_paused:=false

func _ready() -> void:
	randomize()
	#base_color = color_rect.color
	current_life = max_life
	SignalManager.game_paused.connect(_on_game_paused)
	day_manager.day_ended.connect(_on_day_end)

func _physics_process(delta: float) -> void:
	if !game_paused:
		
		if knockback_velocity.length() > 10 : 
			velocity = knockback_velocity
			var knockback_length : float = move_toward(knockback_velocity.length(), 0.0, knockback_friction * delta)
			knockback_velocity = knockback_velocity.normalized() * knockback_length
		
		elif player:
			velocity = (player.global_position - global_position).normalized() * speed
			
		move_and_slide()
		chained_impacts()


func _process(_delta: float) -> void:
	pass


func sprite_update(target_pos : Vector2)->void :
	if velocity.length_squared() <= 2500: 
		return
	sprite.look_at(target_pos)

func get_impact(car_forward : Vector2, car_right : Vector2, player_speed_ratio : float) -> void : 
	var impact_on_enemy : Vector2 = global_position - get_tree().get_first_node_in_group("player").global_position
	var lateral_dot : float = impact_on_enemy.dot(car_right)
	var forward_dot : float = impact_on_enemy.dot(car_forward)
	
	var impact_is_frontal : bool = abs(lateral_dot) < 30 and forward_dot > 0
	
	var push_direction : Vector2
	if impact_is_frontal:
		var random_side_push : float = 1.0 if randf() > 0.5 else -1.0
		push_direction = car_right * random_side_push * side_impact_ratio + car_forward * (front_impact_ratio)
	else:
		var side : int = sign(lateral_dot)
		push_direction = car_right * side + car_forward * side_impact_ratio
	
	knockback_velocity = push_direction.normalized() * impact_force * player_speed_ratio


func chained_impacts() -> void:
	if knockback_velocity.length_squared() < chained_impacts_threshold * chained_impacts_threshold:
		return
	for i in get_slide_collision_count():
		var collider : Node2D = get_slide_collision(i).get_collider()
		if collider.is_in_group("ennemies"):
			var push_dir : Vector2 = (collider.global_position - global_position).normalized()
			var transferred_ratio : float = (knockback_velocity.length() / impact_force) * losing_strenght_ratio
			collider.get_impact(push_dir, transferred_ratio)


func get_damages(damages: int) -> void:
	if not game_paused:
		damage_timer.start()
		current_life -= damages
		if current_life <=0:
			current_life = 0
			call_deferred("on_death")
		$AnimatedSprite2D.self_modulate = Color.RED
		#display_damages(damages)
	

func activate(spawn_position: Vector2) -> void:
	global_position = spawn_position
	#ennemy_spawner.activated_enemies(1)
	current_life = max_life
	

func _on_damage_timer_timeout() -> void:
	$AnimatedSprite2D.self_modulate = Color.WHITE

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause

func on_death() -> void:
	#is_dead = true
	if nb_xp ==1:
		blow_up(global_position)
		collision_box.set_deferred("disabled",true)
		nb_xp = 0
		var xp :=xp_scene.instantiate()
		get_parent().add_child(xp)
		xp.spawn(global_position)
		#ennemy_spawner.activated_enemies(-1)
		StatsManager.frags +=1
		SignalManager.emit_signal("enemy_is_dead",self, self.horde)
	

func _on_hitbox_entered(area: Area2D) -> void:
	if not area.is_in_group("player"): return
	player = area.get_parent()
	if "get_damages_from_mob" in player:
		player.get_damages_from_mob(damages_on_player)
	damage_timer_on_player.start()


func _on_hitbox_exited(area: Area2D) -> void:
	if not area.is_in_group("player"): return
	player = null
	damage_timer_on_player.stop()
		

func _on_damage_timer_on_player_timeout() -> void:
	if player == null: return
	if "get_damages_from_mob" in player:
		player.get_damages_from_mob(damages_on_player)


func display_damages(damages : int)-> void:
	var text : Node2D = damages_text.instantiate()
	var text_offsetX : float = randf_range(-10,10)
	var text_offsetY : float = randf_range(-10,0)
	text.this_label_text = str(damages)
	add_child(text)
	text.global_position = Vector2(damages_text_pos.global_position.x + text_offsetX, damages_text_pos.global_position.y + text_offsetY)

func blow_up(blood_position: Vector2) -> void:
	if blood_particles:
		var blood : CPUParticles2D = blood_particles.instantiate()
		get_node("/root/World/VFX").add_child(blood)
		blood.global_position = blood_position
		

func _on_day_end(_day_end : bool) -> void : 
	speed *= night_speed_boost


func _on_horde_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("ennemies") and body != self:
		horde_neighbors.append(body)


func _on_horde_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("ennemies") and horde_neighbors.has(body):
		horde_neighbors.erase(body)
