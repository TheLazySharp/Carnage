## ennemy.gd — VERSION MULTIMESH
##
## Modifications par rapport à l'original :
##   - Plus d'AnimatedSprite2D dans la scène (à supprimer du node tree)
##   - S'enregistre auprès du ZombieMultiMeshRenderer au _ready()
##   - Se désenregistre avant queue_free()
##   - sprite_update() remplacée par un simple flip via le renderer
##
## SETUP SCÈNE :
##   - Supprimer le nœud AnimatedSprite2D de la scène Enemy
##   - Le nœud DamageTimer_Get et les autres restent en place
##   - Le renderer doit exister dans l'arbre de scène

extends CharacterBody2D
class_name Enemy

@export var max_life: int = 10
@onready var current_life: int
var damages_on_player: float = 1
var speed: float = 40
var nb_xp: int = 1
var is_leader: bool = false
@export var leader: Enemy = null
var horde: Array
var horde_neighbors: Array
var night_speed_boost: float = 1.5

@onready var state_machine: Node = $StateMachine
@onready var player: Node2D = null

# ─── MULTIMESH ───────────────────────────────
## Référence au renderer central (assignée automatiquement au _ready)
var _renderer: ZombieMultiMeshRenderer = null
## Index de cette instance dans le MultiMesh (-1 = non enregistré)
var _mm_index: int = -1

## Chemin vers le renderer dans la scène — ajuste si besoin
@export var renderer_path: NodePath = NodePath("/root/World/ZombieMultiMeshRenderer")
# ─────────────────────────────────────────────

# IMPACT ON PLAYER
@export var impact_force: float = 200.0
@export var knockback_friction: float = 300.0
@export var chained_impacts_threshold: float = 200.0
var knockback_velocity := Vector2.ZERO
var losing_strenght_ratio: float = 0.6
var side_impact_ratio: float = 0.3
var front_impact_ratio: float = -1.2

@export var xp_scene: PackedScene

# UI
@onready var damages_text_pos: Marker2D = get_node("MarkerDamages")
@export var damages_text: PackedScene
@onready var damage_timer: Timer = $DamageTimer_Get
@onready var damage_timer_on_player: Timer = $DamageTimer_OnPlayer
@export var blood_particles: PackedScene = null

@onready var collision_box: CollisionShape2D = $CollisionShape2D

# GAME
@onready var day_manager: Node = $/root/World/DayManager
var day_is_ended: bool = false
var game_paused := false


func _ready() -> void:
	current_life = max_life
	SignalManager.game_paused.connect(_on_game_paused)
	day_manager.day_ended.connect(_on_day_end)

	# Enregistrement auprès du renderer MultiMesh
	_renderer = get_node_or_null(renderer_path)
	if _renderer:
		_mm_index = _renderer.register_enemy(self)
	else:
		push_error("Enemy : ZombieMultiMeshRenderer introuvable au chemin : " + str(renderer_path))


func _physics_process(delta: float) -> void:
	if !game_paused:

		if knockback_velocity.length() > 10:
			velocity = knockback_velocity
			var knockback_length: float = move_toward(knockback_velocity.length(), 0.0, knockback_friction * delta)
			knockback_velocity = knockback_velocity.normalized() * knockback_length

		elif player:
			velocity = (player.global_position - global_position).normalized() * speed

		move_and_slide()
		chained_impacts()


func _process(_delta: float) -> void:
	if current_life <= 0:
		current_life = 0
		on_death()


## Anciennement utilisée pour orienter l'AnimatedSprite2D.
## Désormais gérée via velocity.x dans le renderer (flip_h automatique).
## Conservée pour éviter les erreurs d'appel depuis les states.
func sprite_update(_target_pos: Vector2) -> void:
	pass


func get_impact(car_forward: Vector2, car_right: Vector2, player_speed_ratio: float) -> void:
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
	# Guard rapide avec length_squared (pas de racine carrée)
	if knockback_velocity.length_squared() < chained_impacts_threshold * chained_impacts_threshold:
		return
	for i in get_slide_collision_count():
		var collider: Node2D = get_slide_collision(i).get_collider()
		if collider.is_in_group("ennemies"):
			var push_dir: Vector2 = (collider.global_position - global_position).normalized()
			var transferred_ratio: float = (knockback_velocity.length() / impact_force) * losing_strenght_ratio
			collider.get_impact(push_dir, transferred_ratio)


func get_damages(damages: int) -> void:
	if not game_paused:
		damage_timer.start()
		current_life -= damages
		# Flash rouge via custom_data du MultiMesh
		_flash_damage()
		display_damages(damages)


## Flash rouge via modulation de l'instance MultiMesh
func _flash_damage() -> void:
	if _renderer == null or _mm_index < 0:
		return
	# Teinte rouge via la couleur d'instance
	multimesh_set_color(Color.RED)
	damage_timer.start()


## Applique une couleur d'instance (tint) sur le MultiMesh
func multimesh_set_color(color: Color) -> void:
	if _renderer == null or _mm_index < 0:
		return
	_renderer.multimesh.set_instance_color(_mm_index, color)


func activate(spawn_position: Vector2) -> void:
	global_position = spawn_position
	current_life = max_life


func _on_damage_timer_timeout() -> void:
	# Retour à la couleur normale
	multimesh_set_color(Color.WHITE)


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

		# ── Désenregistrement MultiMesh AVANT queue_free ──
		if _renderer and _mm_index >= 0:
			_renderer.unregister_enemy(_mm_index)
			_mm_index = -1

		SignalManager.emit_signal("enemy_is_dead", self)


func _on_hitbox_entered(area: Area2D) -> void:
	if not area.is_in_group("player"):
		return
	player = area.get_parent()
	if "get_damages_from_mob" in player:
		player.get_damages_from_mob(damages_on_player)
	damage_timer_on_player.start()


func _on_hitbox_exited(area: Area2D) -> void:
	if not area.is_in_group("player"):
		return
	player = null
	damage_timer_on_player.stop()


func _on_damage_timer_on_player_timeout() -> void:
	if player == null:
		return
	if "get_damages_from_mob" in player:
		player.get_damages_from_mob(damages_on_player)


func display_damages(damages: int) -> void:
	var text: Node2D = damages_text.instantiate()
	# randf_range() global — pas besoin de RandomNumberGenerator.new()
	var text_offsetX: float = randf_range(-10.0, 10.0)
	var text_offsetY: float = randf_range(-10.0, 0.0)
	text.this_label_text = str(damages)
	add_child(text)
	text.global_position = Vector2(
		damages_text_pos.global_position.x + text_offsetX,
		damages_text_pos.global_position.y + text_offsetY
	)


func blow_up(blood_position: Vector2) -> void:
	if blood_particles:
		var blood: CPUParticles2D = blood_particles.instantiate()
		get_node("/root/World/VFX").add_child(blood)
		blood.global_position = blood_position


func _on_day_end(_day_end: bool) -> void:
	speed *= night_speed_boost


func _on_horde_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("ennemies") and body != self:
		horde_neighbors.append(body)


func _on_horde_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("ennemies") and horde_neighbors.has(body):
		horde_neighbors.erase(body)


## Permet aux states de changer l'animation (ex: depuis EnemyChase)
## Usage : enemy.set_animation_state("attack")
func set_animation_state(state_name: String) -> void:
	if _renderer and _mm_index >= 0:
		_renderer.set_enemy_state(_mm_index, state_name)
