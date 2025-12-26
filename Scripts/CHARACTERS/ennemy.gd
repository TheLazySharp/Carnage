class_name Enemy
extends CharacterBody2D

@export var max_life: int = 10
@onready var current_life: int
var damages_on_player: float = 10
var speed: float = 40
var player: Node = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var target: Node2D = $"/root/World/Car"
@onready var ennemy_spawner: Node2D = $/root/World/Car/Camera2D/ennemy_spawner

@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:=false

@export var damages_text: PackedScene
@export var xp_scene: PackedScene

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var path_timer: Timer = $path_Timer
@onready var damages_text_pos = get_node("MarkerDamages")

#@onready var color_rect = get_node("ColorRect")
@onready var damage_timer: Timer = $DamageTimer_Get
@onready var base_color: Color
@onready var damage_timer_on_player: Timer = $DamageTimer_OnPlayer

@onready var collision_box: CollisionShape2D = $CollisionShape2D

@export var blood_particles : PackedScene = null

var is_activated:= false

func _ready() -> void:
	randomize()
	#base_color = color_rect.color
	current_life = max_life
	gm_scene.game_paused.connect(_on_game_paused)

func _physics_process(_delta: float) -> void:
	if not game_paused:
		if not navigation_agent.is_target_reached():
			var nav_point_direction = to_local(navigation_agent.get_next_path_position()).normalized()
			velocity = nav_point_direction * speed
			move_and_slide()
			

func _process(_delta: float) -> void:
	if is_activated:
		var dir = target.global_position - global_position
		if abs(dir.x) > abs(dir.y):
			if dir.x > 0:
				sprite.play("right")
			else : 
				sprite.play("left")


		else:
			if dir.y > 0:
				sprite.play("down")

			else : 
				sprite.play("up")


		if current_life <=0:
			current_life = 0
			blow_up(global_position)
			collision_box.set_deferred("disabled",true)
			var xp :=xp_scene.instantiate()
			get_parent().add_child(xp)
			xp.spawn(global_position)
			desactivate() 


func _on_timer_timeout() -> void:
	if is_activated:
		if navigation_agent.target_position != target.global_position:
			navigation_agent.target_position = target.global_position
		path_timer.start()

func get_damages(damages: int) -> void:
	if not game_paused and is_activated:
		print("enemy receives : ", damages)
		damage_timer.start()
		current_life -= damages
		#color_rect.color= Color("ffffff")
		display_damages(damages)
	

func activate(spawn_position: Vector2):
	if !is_activated:
		is_activated = true
		global_position = spawn_position
		visible = true
		collision_box.set_deferred("disabled",false)
		set_process(true)
		set_physics_process(true)
		navigation_agent.target_position = target.global_position
		path_timer.start()
		current_life = max_life


func desactivate():
	set_process(false)
	set_physics_process(false)
	self.is_activated = false
	self.hide()
	self.global_position = Vector2( -50, -50)
	if ennemy_spawner:
		ennemy_spawner.add_enemy_to_pool(self)
		self.navigation_agent.target_position = global_position


func _on_damage_timer_timeout() -> void:
	#color_rect.color = base_color
	pass

func _on_game_paused(game_on_pause) -> void:
	game_paused = game_on_pause


func _on_hitbox_entered(area: Area2D) -> void:
	if is_activated:
		if not area.is_in_group("player"): return #mettre junior dedans
		#print("ennemy hits player")
		player = area.get_parent()
		if "take_damages" in player:
			player.take_damages(damages_on_player)
		damage_timer_on_player.start()


func _on_hitbox_exited(area: Area2D) -> void:
	if is_activated:
		if not area.is_in_group("player"): return
		#print("ennemy exit player")
		player = null
		damage_timer_on_player.stop()
		

func _on_damage_timer_on_player_timeout() -> void:
	if is_activated:	
		if player == null: return
		if "take_damages" in player:
			player.take_damages(damages_on_player)

func display_damages(damages)-> void:
	if is_activated:
		var text = damages_text.instantiate()
		var text_offsetX = RandomNumberGenerator.new().randf_range(-10,10)
		var text_offsetY = RandomNumberGenerator.new().randf_range(-10,0)
		text.this_label_text = str(damages)
		add_child(text)
		text.global_position = Vector2(damages_text_pos.global_position.x + text_offsetX, damages_text_pos.global_position.y + text_offsetY)

func blow_up(blood_position: Vector2):
	if blood_particles:
		var blood = blood_particles.instantiate()
		get_node("/root/World/VFX").add_child(blood)
		blood.global_position = blood_position
