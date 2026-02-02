extends CharacterBody2D
class_name Enemy

@export var max_life: int = 10
@onready var current_life: int
var damages_on_player: float = 1
var speed: float = 40
var player: Node = null
var is_from_the_horde:=false
var nb_xp: int =1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

#@onready var target: Node2D = $"/root/World/Car"
@onready var ennemy_spawner: Node2D = $/root/World/Spawners/ennemy_spawner

@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:=false

@export var damages_text: PackedScene
@export var xp_scene: PackedScene

#@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
#@onready var path_timer: Timer = $path_Timer
@onready var damages_text_pos : Marker2D = get_node("MarkerDamages")

#@onready var color_rect = get_node("ColorRect")
@onready var damage_timer: Timer = $DamageTimer_Get
@onready var base_color: Color
@onready var damage_timer_on_player: Timer = $DamageTimer_OnPlayer

@onready var collision_box: CollisionShape2D = $CollisionShape2D

@export var blood_particles : PackedScene = null


func _ready() -> void:
	randomize()
	#base_color = color_rect.color
	current_life = max_life
	gm_scene.game_paused.connect(_on_game_paused)

func _physics_process(_delta: float) -> void:
	if !game_paused:
		move_and_slide()
			

func _process(_delta: float) -> void:
	if abs(velocity.x) > abs(velocity.y):
		if velocity.x > 0:
			sprite.play("right")
		else : 
			sprite.play("left")

	else:
		if velocity.y > 0:
			sprite.play("down")

		else : 
			sprite.play("up")

	if current_life <=0:
		current_life = 0
		on_death()




func get_damages(damages: int) -> void:
	if not game_paused:
		#print("enemy receives : ", damages)
		damage_timer.start()
		current_life -= damages
		#color_rect.color= Color("ffffff")
		display_damages(damages)
	

func activate(spawn_position: Vector2) -> void:
	global_position = spawn_position
	ennemy_spawner.activated_enemies(1)
	current_life = max_life
	

func _on_damage_timer_timeout() -> void:
	#color_rect.color = base_color
	pass

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause

func on_death() -> void:
	blow_up(global_position)
	collision_box.set_deferred("disabled",true)
	if nb_xp ==1:
		nb_xp = 0
		var xp :=xp_scene.instantiate()
		get_parent().add_child(xp)
		xp.spawn(global_position)
	ennemy_spawner.activated_enemies(-1)
	StatsManager.frags +=1
	SignalManager.emit_signal("enemy_is_dead",self)
	

func _on_hitbox_entered(area: Area2D) -> void:
	if not area.is_in_group("player"): return #mettre junior dedans
	#print("ennemy hits player")
	player = area.get_parent()
	if "take_damages" in player:
		player.take_damages(damages_on_player)
	damage_timer_on_player.start()


func _on_hitbox_exited(area: Area2D) -> void:
	if not area.is_in_group("player"): return
	#print("ennemy exit player")
	player = null
	damage_timer_on_player.stop()
		

func _on_damage_timer_on_player_timeout() -> void:
	if player == null: return
	if "take_damages" in player:
		player.take_damages(damages_on_player)


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
