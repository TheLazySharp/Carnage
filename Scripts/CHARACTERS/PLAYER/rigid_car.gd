extends CharacterBody2D

var player : CarData

#CAR DATA

var max_backward_speed : int
var friction : float
var turn_speed : float
var velocity_floor : int
var burnout_boost : int
@onready var car_sprite: Sprite2D = $CarSprite
@onready var camera_2d: Camera2D = $/root/World/Car/Camera2D

#SFX
@onready var start_engine: AudioStreamPlayer = $Audio/StartEngine
var start_engine_sound : AudioStreamMP3
@onready var dmg_sfx: AudioStreamPlayer = $Audio/DmgSFX
@onready var dmg_sfx_2: AudioStreamPlayer = $Audio/DmgSFX2
@onready var dmg_sfx_3: AudioStreamPlayer = $Audio/DmgSFX3
var dmg_players : Array[AudioStreamPlayer]
@onready var death_sfx: AudioStreamPlayer = $Audio/DeathSfx
@onready var engine_sfx_player: Node = $Audio/Engine


#SKID

@onready var rear_left: Marker2D = $RearLeft
@onready var rear_right: Marker2D = $RearRight
var drifting : bool

#DRIFT and BURN
@onready var drift_manager: Node2D = $DriftManager
@onready var bloody_engine: Node2D = $BloodyEngine
@onready var rear_left_burn_anim: AnimatedSprite2D = $RearLeft/RearLeftBurnAnim
@onready var rear_right_burn_anim: AnimatedSprite2D = $RearRight/RearRightBurnAnim
signal burnout_ok(burnout : bool)
var burning : bool
signal revving(revving : bool)
var revving_start : bool = false
signal dashing
var can_dash : bool = false
var is_dashing : bool = false
var dash_timer : float = 0
var original_friction : float = 0
signal dash_end

#INVINCIBLE
@onready var collision_shape: CollisionShape2D = $CollisionShape

#CAM SHAKE
var shake_timer : float = 0
var shake_timer_steps : float = 1

#GHOSTING
@onready var ghost_timer: Timer = $GhostTimer
@export var ghost_scene : PackedScene

#GAME
@onready var ready_go: Label = $/root/World/CanvasLayer/Texts/ReadyGo
@onready var explosives: Node2D = $"../Explosives"

signal game_over(game_is_over: bool)
signal start_time(game_start: bool)
signal engine_ignited
#signal stats_initiated
var game_is_over:= false
var game_paused:=false
var is_taking_damages:=false
var can_drive:=false


#@onready var gate: CharacterBody2D = $"../StartingGate"
#var full_command : bool
var forward_only : bool = false

#UI
#LIFE
@onready var life_bar: ProgressBar = $"/root/World/CanvasLayer/HUD/LifeGauge"
@onready var life_label: Label = $"/root/World/CanvasLayer/HUD/LifeGauge/LifeLabel"
@onready var taking_damages: Timer = $TakingDamages
#@onready var speed_label: Label = $"/root/World/CanvasLayer/HUD/Speed"

#VFX
@onready var car_explosion: AnimatedSprite2D = $VFX/CarExplosion
@onready var sparkles: CPUParticles2D = $VFX/Sparkles
@onready var drivin_smoke_r_2: CPUParticles2D = $RearRight/DrivinSmokeR2
@onready var drivin_smoke_l_2: CPUParticles2D = $RearLeft/DrivinSmokeL2
@onready var flash: AnimationPlayer = $CarSprite/Flash

#INVINCIBILITY
var invincibility_tween : Tween = null
var glow_sprite : Sprite2D = null
#@onready var invincibility_particles: CPUParticles2D = $VFX/InvincibilityStars  # à créer 

# ---- AUTOPILOT ----
enum AutopilotState { NONE, ZOOM, DRIVE, EXIT }
var autopilot_state : AutopilotState = AutopilotState.NONE

var autopilot_speed : float = 0.0
var autopilot_exit_accel : float = 800.0
var zoom_tween : Tween = null
var autopilot_zoom_locked : bool = false
var autopilot_target_zoom : float = 1.5


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("dash") and can_dash and !game_paused:
		dash()

func _ready() -> void:
	player = CarManager.selected_car
	if TimeManager.current_day ==1:
		player.init_stats()
	
	rear_left_burn_anim.hide()
	rear_right_burn_anim.hide()
	##TEST
	#WeaponsManager.test_weapons()
	
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.boost_gauge_is_full.connect(_on_boost_full)
	SignalManager.start_autopilot_transition.connect(_on_autopilot_transition_start)
	SignalManager.end_autopilot_transition.connect(_on_exit_transition)
	SignalManager.player_invincible.connect(_on_invincible) 
	ItemManager.repair.connect(_on_repair_picked_up)


	#DRIVING
	max_backward_speed = roundi(player.max_speed.get_value() * 0.8)

	friction = player.friction
	turn_speed = player.turn_speed
	velocity_floor = player.velocity_floor
	burnout_boost = player.burnout_boost
	
	#DRIFT
	drift_manager.init_drift(self,player,rear_left,rear_right)

	#FUEL
	bloody_engine.init_bloody_engine(player,car_sprite)
	
	#AUDIO
	start_engine_sound = player.start_engine_Sound
	dmg_players = [dmg_sfx, dmg_sfx_2, dmg_sfx_3]
	
	#VFX
	car_sprite.texture = player.car_sprite
	
	#LIFE
	if TimeManager.current_day == 1 : 
		player.current_life = int(player.max_life.get_value())

	life_bar.max_value = player.max_life.get_value()
	life_bar.value = player.current_life
	life_label.text = str(player.current_life) + "/" + str(int(player.max_life.get_value()))
	
	if visible:
		emit_signal("engine_ignited")
		start_engine.play()

func _process(_delta: float) -> void:
	if !game_paused:
		#speed_label.text  = str(roundi(velocity.length()/player.max_speed.get_value() * player.display_max_speed.get_value()))
		life_label.text = str(player.current_life) + "/" + str(int(player.max_life.get_value()))

func _physics_process(delta : float) -> void:
	if !game_paused and can_drive and !game_is_over:
		match autopilot_state:
			AutopilotState.NONE:
				_process_player_inputs(delta)
			AutopilotState.ZOOM:
				_process_autopilot_zoom(delta)
			AutopilotState.DRIVE:
				_process_autopilot_drive(delta)
			AutopilotState.EXIT:
				_process_autopilot_exit(delta)

# ----------------- CAMERA JUICE -----------------
		if autopilot_state !=AutopilotState.EXIT:
			camera_2d.update_lookahead(velocity)
			if !autopilot_zoom_locked:
				camera_2d.update_zoom(velocity.length())
			#else :
				#camera_2d.zoom = Vector2.ONE * autopilot_target_zoom

func _process_player_inputs(delta : float) -> void : 
	if !game_paused and can_drive and !game_is_over:
		engine_sfx_player.update_engine_sfx(velocity.length(), revving_start)
		player.drifting = drifting
		
		var forward := Vector2.RIGHT.rotated(rotation)
		var lateral := forward.rotated(PI / 2)

		# ----------------- INPUTS -----------------
		var throttle := Input.get_action_strength("accelerate")
		var steer := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		drifting = Input.is_action_pressed("drift") and throttle > 0
		burning = Input.is_action_pressed("accelerate") and Input.is_action_pressed("drift") and velocity.length_squared() < 4
		
		if forward_only:
			throttle = Input.get_action_strength("accelerate")
			steer = 0
			drifting = false
		
		if !Input.is_action_pressed("accelerate"):
			throttle = - Input.get_action_strength("back")
		else : 
			throttle = Input.get_action_strength("accelerate")
		
		# ----------------- BURNOUT -----------------
		
		if burning :
			if !revving_start:
				revving_start = true
				emit_signal("revving", revving_start)
			throttle = 0
			rear_left_burn_anim.show()
			if !rear_left_burn_anim.is_playing():
				rear_left_burn_anim.play("fadeIn")
			rear_right_burn_anim.show()
			if !rear_right_burn_anim.is_playing():
				rear_right_burn_anim.play("fadeIn")
			
			if !Input.is_action_pressed("accelerate"): 
				revving_start = false
				emit_signal("revving", revving_start)
				burning = false
				emit_signal("burnout_ok",burning)
				
		
		if Input.is_action_pressed("drift") and Input.is_action_just_released("accelerate"):
				revving_start = false
				emit_signal("revving", revving_start)

			
		if Input.is_action_pressed("accelerate") and Input.is_action_just_released("drift") and velocity.length() <1:
			rear_left_burn_anim.play("fadeOut")
			rear_right_burn_anim.play("fadeOut")
			#print("BURNOUT !")
			burning = false
			emit_signal("burnout_ok",burning)
			revving_start = false
			emit_signal("revving", revving_start)
			throttle = burnout_boost
			if can_dash:
				dash()
		

		if rear_right_burn_anim.animation == "idle" and !burning:
			rear_right_burn_anim.play("fadeOut")


		if rear_left_burn_anim.animation == "idle" and !burning:
			rear_left_burn_anim.play("fadeOut")

		
		# ----------------- ACCELERATION -----------------
		if throttle != 0:
			velocity += forward * throttle * player.acceleration.get_value() * delta
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

		velocity = velocity.limit_length(player.max_speed.get_value())
		
		if throttle < 0 : 
			velocity = velocity.limit_length(max_backward_speed)
			
		# ----------------- ROTATION -----------------
		var speed := velocity.dot(forward)
		var steer_factor : float = clamp(abs(speed) / player.max_speed.get_value(), 0.25, 1.0)

		if drifting:
			steer *= player.drift_turn_bonus.get_value()

		rotation += steer * turn_speed * steer_factor * delta

		var forward_velocity := forward * velocity.dot(forward)
		var lateral_velocity := lateral * velocity.dot(lateral)

		velocity = drift_manager.update_drift(delta,drifting,forward_velocity,lateral_velocity,forward,velocity)
		
		
		# ----------------- COLLISION -----------------
		var motion : Vector2 = velocity * delta
		var collision : KinematicCollision2D = move_and_collide(motion)
		if collision:
			## ------ WITH ENEMIES
			var collider := collision.get_collider()

			if collider.is_in_group("walls"):
			# ------ WITH WALLS
				var n : Vector2 = collision.get_normal().normalized()
				
				velocity = velocity.slide(n) * 0.9
				
				var wall_tan := Vector2(-n.y, n.x)
				var is_moving_forward : bool = velocity.dot(forward) > 0
				
				if velocity.dot(wall_tan) < 0 : 
					wall_tan = - wall_tan
				
				var new_speed : float = velocity.length()
				velocity = velocity.normalized().lerp(wall_tan,0.3) * new_speed
				
				var target_rotation : float = wall_tan.angle()
				if !is_moving_forward:
					target_rotation += PI
				
				rotation = lerp_angle(rotation, target_rotation, 5.0 * delta)
				
				if drifting :
					SignalManager.emit_signal("wall_collision")
					drifting = false
					drift_manager.force_stop_skid()

		#VFX
		if Input.is_action_just_pressed("accelerate") or Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right") :
			play_drivin_smokes()
			
		if is_dashing:
			if !game_paused:
				dash_timer -= delta
			if dash_timer <= 0:
				end_dash()

func _process_autopilot_zoom(delta : float) -> void:
	var forward := Vector2.RIGHT.rotated(rotation)
	velocity = velocity.move_toward(forward * player.max_speed.get_value(), 60.0 * delta)
	var motion := velocity * delta
	move_and_collide(motion)
	engine_sfx_player.update_engine_sfx(velocity.length(), false)

func _process_autopilot_drive(delta : float) -> void:
	var forward := Vector2.RIGHT
	rotation = lerp_angle(rotation, 0.0, 3.0 * delta) #heldp the car face right
	autopilot_speed = move_toward(autopilot_speed, player.max_speed.get_value(), player.acceleration.get_value() * delta)
	velocity = (forward * autopilot_speed).limit_length(player.max_speed.get_value())
	var motion := velocity * delta
	move_and_collide(motion)
	engine_sfx_player.update_engine_sfx(velocity.length(), false)

func _process_autopilot_exit(delta : float) -> void:
	var forward := Vector2.RIGHT
	rotation = lerp_angle(rotation, 0.0, 5.0 * delta)
	autopilot_speed += autopilot_exit_accel * delta
	velocity = (forward * autopilot_speed).limit_length(player.max_speed.get_value() + 30)
	
	var motion := velocity * delta
	move_and_collide(motion)
	engine_sfx_player.update_engine_sfx(velocity.length(), false)

func _on_game_paused(game_on_pause :bool) -> void:
	game_paused = game_on_pause

func get_damages_from_mob(damages_on_player: int) -> void:
	if player.invincible:
		return
	if not game_paused and !game_is_over and velocity.length() < velocity_floor:
		is_taking_damages = true
		player.current_life -= damages_on_player
		sparkles.emitting = true
		damages_sfx()
		life_bar.value = player.current_life
		#display_damages(damages_on_player)
		#print("car get ",damages_on_player," dmg. Current life : ",str(current_life))
		#animation_player.play("beaver_animations/flash")
		flash.play("flash")
		taking_damages.start()
		
		if player.current_life <=0:
			player.current_life = 0
			on_death()
			return
			
		if is_taking_damages:return

func get_damages(damages_on_player: int) -> void:
	if player.invincible:
		return
	if not game_paused and !game_is_over:
		player.current_life -= damages_on_player
		life_bar.value = player.current_life
		sparkles.emitting = true
		flash.play("flash")

		if player.current_life <=0:
			player.current_life = 0
			on_death()
			return

func on_death() -> void:
	can_drive = false
	is_taking_damages = false
	WeaponsManager.activate_weapons(false)
	#WeaponsManager.unload()
	end_dash()
	bloody_engine.set_process(false)
	car_sprite.modulate = Color.WHITE
	stop_invincibility_vfx()
	car_sprite.hide()
	drift_manager.force_stop_skid()
	collision_shape.set_deferred("disabled",true)
	car_explosion.play("Explosion")
	death_sfx.play()
	camera_2d.screen_shake(15,1)
	game_is_over = true
	SignalManager.emit_signal("game_is_over",game_is_over) #Emitted to other autoload managers (enemies...)
	#animated_sprite.hide()
	await get_tree().create_timer(2).timeout
	queue_free()
	emit_signal("game_over", game_is_over) #Emitted to the ScenesManager to load GameOver scene
	
	
#func display_damages(_damages)-> void:
	#if !game_is_over:
		#pass
		##var text = damages_text.instantiate()
		##var text_offsetX = RandomNumberGenerator.new().randf_range(-10,10)
		##var text_offsetY = RandomNumberGenerator.new().randf_range(-10,0)
		##text.this_label_text = "- " +str(damages)
		##add_child(text)
		##text.global_position = Vector2(damages_text_pos.global_position.x + text_offsetX, damages_text_pos.global_position.y + text_offsetY)

func _on_taking_damages_timeout() -> void:
	is_taking_damages = false
	#animation_player.stop()

#func _on_body_parts_area_entered(area: Area2D) -> void:
	#if !game_paused and velocity.length() >= velocity_floor:
		#if area.is_in_group("ennemies") and "get_damages" in area:
			#area.get_damages(roundi(player.dmg.get_value()))
			#StatsManager.total_car_dmg += roundi(player.dmg.get_value())
		#else : return

func _on_start_engine_finished() -> void:
	can_drive = true
	emit_signal("start_time", can_drive)
	SignalManager.emit_signal("start_timer")
	WeaponsManager.activate_weapons(true)

func _on_full_command(full_command : bool) -> void:
	if !full_command:
		can_drive = false

func _on_forward_only(car_only_forward : bool) -> void:
	forward_only = car_only_forward

func angle_difference(from: float, to: float) -> float:
	var diff := fmod(to - from, TAU)
	return fmod(2.0 * diff, TAU) - diff

func _on_rear_left_burn_anim_animation_finished() -> void:
	if burning:
		rear_left_burn_anim.play('idle')
	else :
		rear_left_burn_anim.play('fadeOut')
	if rear_left_burn_anim.animation == "fadeOut":
		rear_left_burn_anim.stop()
		rear_left_burn_anim.hide()

func _on_rear_right_burn_animation_finished() -> void:
	if burning:
		rear_right_burn_anim.play('idle')
	else :
		rear_right_burn_anim.play('fadeOut')
	if rear_right_burn_anim.animation == "fadeOut" and !burning:
		rear_right_burn_anim.stop()
		rear_right_burn_anim.hide()

func add_ghost()-> void: 
	var ghost : Node2D = ghost_scene.instantiate()
	ghost.set_property(position, scale, rotation)
	get_tree().current_scene.add_child(ghost)

func _on_ghost_timer_timeout() -> void:
	add_ghost()

func dash() -> void :
	if player.current_fuel < player.dash_fuel_down:
		return
	emit_signal("dashing")
	can_dash = false

	Engine.time_scale = 0.08
	await get_tree().create_timer(0.08 * 0.08).timeout
	Engine.time_scale = 1.0

	camera_2d.screen_shake(12, 0.4)

	var mod_dmg := Modifier.new(player.dash_dmg_bonus.get_value(), Modifier.Type.PERCENT_MULT, "dmg_dash_bonus", player.dash_duration.get_value())
	var mod_max_speed := Modifier.new(1.25, Modifier.Type.PERCENT_MULT, "max_speed_dash_modifier", player.dash_duration.get_value())
	var mod_display_max_speed := Modifier.new(90, Modifier.Type.FLAT, "display_max_speed_dash_modifier", player.dash_duration.get_value())
	var mod_torque := Modifier.new(2, Modifier.Type.PERCENT_MULT, "torque_dash_modifier", player.dash_duration.get_value())
	player.dmg.add_temp_modifier(mod_dmg)
	player.max_speed.add_temp_modifier(mod_max_speed)
	player.display_max_speed.add_temp_modifier(mod_display_max_speed)
	player.acceleration.add_temp_modifier(mod_torque)
	
	
	var forward := Vector2.RIGHT.rotated(rotation)
	velocity += forward * player.max_speed.get_value()

	original_friction = friction
	friction = 10.0
	dash_timer = player.dash_duration.get_value()
	is_dashing = true
	ghost_timer.start()

func end_dash() -> void:
	is_dashing = false
	dash_timer = 0.0
	friction = original_friction
	ghost_timer.stop()
	emit_signal("dash_end")

func _on_boost_full() -> void:
	can_dash = true

func damages_sfx()-> void : 
	if game_paused or game_is_over:
		return
	for dmg_player in dmg_players:
		if !dmg_player.playing:
			dmg_player.play()
			return

func play_drivin_smokes() -> void : 
	if game_paused or game_is_over:
		return
	drivin_smoke_r_2.emitting = true
	drivin_smoke_l_2.emitting = true

func get_drift_factor() -> float:
	return drift_manager.get_drift_factor()

func _on_autopilot_transition_start() -> void : 
	autopilot_state = AutopilotState.ZOOM
	autopilot_speed = velocity.length()
	autopilot_zoom_locked = true
	camera_2d.lookahead_strength = 0.0
	camera_2d.lookahead_offset = Vector2.ZERO

	if zoom_tween:
		zoom_tween.kill()
	zoom_tween = create_tween()
	zoom_tween.tween_property(camera_2d, "target_zoom", autopilot_target_zoom, 2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	zoom_tween.tween_callback(_on_zoom_complete)

func _on_zoom_complete() -> void:
	autopilot_state = AutopilotState.DRIVE

func _on_exit_transition() -> void : 
	autopilot_state = AutopilotState.EXIT
	autopilot_zoom_locked = false
	camera_2d.top_level = true #camera fixed
	camera_2d.global_position = global_position

	await get_tree().create_timer(2.0).timeout
	SceneManager.load_level(SceneManager.SCENES.ROADMAP)

func _on_invincible(player_invincible : bool) -> void : 
	if player_invincible:
		start_invincibility_vfx()
	else:
		stop_invincibility_vfx()

func start_invincibility_vfx() -> void:
	print("start invincibility pulse")
	# --- GLOW SPRITE ---
	if glow_sprite == null:
		glow_sprite = Sprite2D.new()
		glow_sprite.offset = car_sprite.offset
		glow_sprite.flip_h = car_sprite.flip_h
		glow_sprite.flip_v = car_sprite.flip_v
		glow_sprite.texture = car_sprite.texture
		glow_sprite.light_mask = car_sprite.light_mask
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow_sprite.material = mat
		glow_sprite.z_index = car_sprite.z_index - 1
		car_sprite.add_child(glow_sprite)

	# --- PULSE ---
	if invincibility_tween:
		invincibility_tween.kill()
	invincibility_tween = create_tween().set_loops()
	invincibility_tween.tween_property(glow_sprite, "modulate",Color(3.0, 2.5, 0.0, 1.0), 0.18).set_trans(Tween.TRANS_SINE)
	invincibility_tween.tween_property(glow_sprite, "modulate",Color(0.0, 0.0, 0.0, 0.0), 0.18).set_trans(Tween.TRANS_SINE)

	# --- ÉTOILES ---
	#invincibility_particles.emitting = true

func stop_invincibility_vfx() -> void:
	if invincibility_tween:
		invincibility_tween.kill()
		invincibility_tween = null
	if glow_sprite:
		glow_sprite.queue_free()
		glow_sprite = null
	#invincibility_particles.emitting = false

func _on_hitbox_area_entered(area: Area2D) -> void:
	if !game_paused and velocity.length() >= velocity_floor:
		if area.is_in_group("ennemies") and "get_damages_from_car" in area:
			area.get_damages_from_car(roundi(player.dmg.get_value()))
			StatsManager.total_car_dmg += roundi(player.dmg.get_value())
		else : return

func _on_repair_picked_up(repair_amount : int) -> void:
	player.current_life += mini((int(player.max_life.get_value() - player.current_life)), repair_amount)
	life_bar.value = player.current_life
