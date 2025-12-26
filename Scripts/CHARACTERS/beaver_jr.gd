extends CharacterBody2D

var max_life : int
var current_life : int

var speed:= 100
var acceleration := 250
var boost:= 4
var back_to_pack_speed:= 4

var farmable_target: Node2D
var farming_power:= 10

@onready var farming_timer: Timer = $FarmingTimer
@onready var taking_damages: Timer = $TakingDamages

@onready var radar: CollisionShape2D = $Radar/DetectionRange
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var animation_player: AnimationPlayer = $Visuals/AnimationPlayer
@onready var wood_vfx: GPUParticles2D = $Visuals/WoodVFX
@onready var farm_spot: Marker2D = $FarmSpot

@onready var beaver_sr: CharacterBody2D = $/root/World/BeaverSr
var offset_pos: Vector2

@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:=false


var is_invincible:= false
var is_taking_damages:= false
var is_being_healed:= false
@export var back_to_pack_threshold: float = 0.3
var is_coming_to_pack:= false

@onready var health_bar: ProgressBar = $HealthBar

@export var damages_text: PackedScene
@onready var damages_text_pos = get_node("MarkerDamages")

var target_pos: Vector2

var resources : Array[Area2D]

enum States {PACKED, PACKING, FOLLOWING, GOING_TO_FARM, FARMING, WALKING_BACK}
var state = States.PACKED
var current_state

func _ready() -> void:
	max_life = 500
	current_life = 300
	gm_scene.game_paused.connect(_on_game_paused)
	health_bar.min_value = 0
	health_bar.max_value = max_life
	health_bar.value = current_life
	farmable_target = null
	current_state = state


func _process(_delta: float) -> void:
	#print(state)
	pass
	

		
func _physics_process(_delta: float) -> void:
	if state == null:
		state = States.FOLLOWING
	
	if state == States.PACKED or state == States.FARMING:
		animated_sprite.play("idle")
		#print("idle")
	if state != States.PACKED and state != States.FARMING: 
		animated_sprite.play("walk")
		#print("walking")
	
	if state == States.PACKED or state == States.FOLLOWING:
		target_pos = beaver_sr.global_position + offset_pos
		if abs(global_position - target_pos).length() < 3:
			state = States.PACKED
		else : 
			state = States.FOLLOWING

	
	
	if Input.is_action_just_released("go_pack") or current_life < max_life * back_to_pack_threshold:
		back_to_pack()
		
	
	if state == States.PACKING:
		radar.set_deferred("disabled", true)
		target_pos = beaver_sr.global_position + offset_pos
		if abs(global_position - target_pos).length() < 3:
			state = States.PACKED
		else : 
			state = States.PACKING
	
	if state != States.PACKING:
		radar.set_deferred("disabled", false)
	
	if !resources.is_empty() and state != States.FARMING:
		target_pos = get_nearest_resource().get_child(1).global_position
		farmable_target = get_nearest_resource().get_parent()
		#print(farmable_target)
		state = States.GOING_TO_FARM
	
	if resources.is_empty() and state != States.PACKING and abs(global_position - target_pos).length() > 3:
		farmable_target = null
		state = States.FOLLOWING

	if !game_paused:
		var direction = position.direction_to(target_pos)
		velocity = velocity.move_toward(direction * speed, acceleration)
		move_and_slide()
	
	
	current_state = state
	
func _on_game_paused(game_on_pause) -> void:
	game_paused = game_on_pause

func spawn(spawn_position: Vector2):
	if not game_paused:
		global_position = spawn_position
		offset_pos = spawn_position - beaver_sr.position


func _on_radar_area_entered(resource: Area2D) -> void:
	if resource.get_collision_layer_value(13) and resource.is_in_group("ressources") and state != States.PACKING:
		resources.append(resource)
		print("resource detected - resources = ",resources.size())



func _on_radar_area_exited(resource: Area2D) -> void:
	if resource.get_collision_layer_value(13) and resource.is_in_group("ressources"):
		resources.erase(resource)
		print("resource exited - resources = ",resources.size())
		farming_timer.stop()
		wood_vfx.emitting = false
		wood_vfx.hide()
		print("farming ended")
		state = States.FOLLOWING


func get_nearest_resource() -> Area2D:
	if resources.is_empty(): return
	var nearest_target = resources[0]
	var shorter_distance = nearest_target.global_position.distance_squared_to(farm_spot.global_position)
	for i in resources.size():
		var target = resources[i]
		var distance = target.global_position.distance_squared_to(farm_spot.global_position)
		if distance < shorter_distance :
			nearest_target = target
			shorter_distance = distance
	return nearest_target

func farm() -> void:
	if !game_paused and state == States.FARMING:
		if farmable_target != null and "take_damages" in farmable_target:
			#farmable_target.take_damages(farming_power)
			#animated_sprite.play("idle")
			farming_timer.start()
			wood_vfx.restart()
			wood_vfx.show()

func _on_farming_timer_timeout() -> void:
	if state == States.FARMING:
		if farmable_target == null:
			state = States.FOLLOWING
			return
		elif "take_damages" in farmable_target:
			print("farming")
			farmable_target.take_damages(farming_power)

func _on_collect_zone_entered(area: Area2D) -> void:
	if area.is_in_group("collectables"):
		XPManager.get_xp(1)
		
	if area.get_collision_layer_value(12) and state == States.GOING_TO_FARM:
		state = States.FARMING
		print("junior in farming area")
		farm()

func back_to_pack() -> void:
	state = States.PACKING
	resources.clear()
	back_to_pack_speed = boost


func process_healing(healing: int) -> void:
	if not game_paused:
		if current_life >= max_life: 
			current_life = max_life
			health_bar.value = current_life
			#print("junior is fully healed")
			
			return
		if current_life < max_life:
			is_being_healed = true
			current_life += healing
			health_bar.value = current_life
			#print("junior is healing : ",current_life)
			is_being_healed = false

func take_damages(damages: int) -> void:
	if not game_paused:
		if not is_invincible:
			is_taking_damages = true
			current_life -= damages
			health_bar.value = current_life
			display_damages(damages)
			print(str(current_life))
			self.animation_player.play("beaverJR_animations/flash")
			taking_damages.start()
			
			if current_life <=0:
				current_life = 0
				health_bar. value = current_life
				play_death()
				return
				
			if is_taking_damages:return

func play_death() -> void:
	is_taking_damages = false
	self.animation_player.stop()
	#print("Beaver Jr is dead god DAM IT")

func _on_taking_damages_timeout() -> void:
	is_taking_damages = false
	animation_player.stop()

	
func display_damages(damages)-> void:
	if not game_paused:
		var text = damages_text.instantiate()
		var text_offsetX = RandomNumberGenerator.new().randf_range(-10,10)
		var text_offsetY = RandomNumberGenerator.new().randf_range(-10,0)
		text.this_label_text = "- " +str(damages)
		add_child(text)
		text.global_position = Vector2(damages_text_pos.global_position.x + text_offsetX, damages_text_pos.global_position.y + text_offsetY)
