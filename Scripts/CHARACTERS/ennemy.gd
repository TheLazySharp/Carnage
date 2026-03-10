extends CharacterBody2D
class_name Enemy

@export var max_life: int = 10
@onready var current_life: int
var damages_on_player: float = 1
var speed: float = 40
var player: Node = null
var is_from_the_horde:=false
var nb_xp: int =1
#var is_dead : bool = false
var is_leader: bool = false
@export var leader: Enemy = null
var horde : Array
var horde_neighbors : Array
var night_speed_boost : float = 1.5
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
#var current_anim : String = ""
@onready var state_machine: Node = $StateMachine



@onready var ennemy_spawner: Node2D = $/root/World/Spawners/ennemy_spawner

var game_paused:=false

@export var damages_text: PackedScene
@export var xp_scene: PackedScene

#@onready var target: Node2D = $"/root/World/Car"
#@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
#@onready var path_timer: Timer = $path_Timer

@onready var damages_text_pos : Marker2D = get_node("MarkerDamages")
#@onready var color_rect = get_node("ColorRect")
@onready var damage_timer: Timer = $DamageTimer_Get
@onready var base_color: Color
@onready var damage_timer_on_player: Timer = $DamageTimer_OnPlayer

@onready var collision_box: CollisionShape2D = $CollisionShape2D

@export var blood_particles : PackedScene = null


@onready var day_manager: Node = $/root/World/DayManager
var day_is_ended : bool = false

func _ready() -> void:
	randomize()
	#base_color = color_rect.color
	current_life = max_life
	SignalManager.game_paused.connect(_on_game_paused)
	day_manager.day_ended.connect(_on_day_end)

func _physics_process(_delta: float) -> void:
	if !game_paused:
		move_and_slide()
			

func _process(_delta: float) -> void:

	#if current_life <=0 and !is_dead:
	if current_life <=0:
		current_life = 0
		on_death()


func sprite_update(target_pos : Vector2)->void : 
	if velocity.length() < 50: 
		return
	sprite.look_at(target_pos)



func get_damages(damages: int) -> void:
	if not game_paused:
		damage_timer.start()
		current_life -= damages
		$AnimatedSprite2D.self_modulate = Color.RED
		display_damages(damages)
	

func activate(spawn_position: Vector2) -> void:
	global_position = spawn_position
	ennemy_spawner.activated_enemies(1)
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
		ennemy_spawner.activated_enemies(-1)
		StatsManager.frags +=1
		SignalManager.emit_signal("enemy_is_dead",self)
	

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
	var text_offsetX : float = RandomNumberGenerator.new().randf_range(-10,10)
	var text_offsetY : float = RandomNumberGenerator.new().randf_range(-10,0)
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
