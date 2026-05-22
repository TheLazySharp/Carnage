extends CharacterBody2D

var player : CarData

#CAR DATA
#--------------- MAINS STATS
var acceleration : float
var max_speed : float
var dash_duration : float
var max_life : float
var damages : float
var dash_dmg_bonus : float
var display_max_speed : float
var nitro_up : float
var collect_radius : float
var drift_turn_bonus : float


var max_backward_speed : int
var friction : float
var turn_speed : float
var velocity_floor : int
var burnout_boost : int
var drift_grip : float
var normal_grip : float
var max_drift_damping : float
var min_drift_speed : float
var snap_grip : float
var snap_speed : float
var current_grip : float
var was_drifting : bool = false
var skid_spacing : float
var skid_lifetime : float
var skid_fade_speed : float
@onready var car_sprite: Sprite2D = $CarSprite
@onready var camera_2d: Camera2D = $/root/World/Car/Camera2D

#SFX
@onready var start_engine: AudioStreamPlayer = $Audio/StartEngine
var start_engine_sound : AudioStreamMP3
@onready var drift_sfx: AudioStreamPlayer2D = $Audio/DriftSfx
@onready var dmg_sfx: AudioStreamPlayer = $Audio/DmgSFX
@onready var dmg_sfx_2: AudioStreamPlayer = $Audio/DmgSFX2
@onready var dmg_sfx_3: AudioStreamPlayer = $Audio/DmgSFX3
var dmg_players : Array[AudioStreamPlayer]
@onready var death_sfx: AudioStreamPlayer = $Audio/DeathSfx
@onready var engine_sfx_player: Node = $Audio/Engine


#SKID
@export var skid_marks_path: NodePath = "$/root/World/SkidMarks"
@onready var skid_parent: Node2D = get_node(skid_marks_path)
@onready var rear_left: Marker2D = $RearLeft
@onready var rear_right: Marker2D = $RearRight
var left_line: Line2D = null
var right_line: Line2D = null
var left_border: Line2D = null
var right_border: Line2D = null
var last_left_pos := Vector2.ZERO
var last_right_pos := Vector2.ZERO
var drifting : bool

#DRIFT and BURN
var drifting_last_frame := false
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

#INVINCIBLE
var is_invincible : bool = false
@onready var collision_shape: CollisionShape2D = $CollisionShape

#CAM SHAKE
var shake_timer : float = 0
var shake_timer_steps : float = 1

#GHOSTING
@onready var ghost_timer: Timer = $GhostTimer
@export var ghost_scene : PackedScene

#GAME
signal game_over(game_is_over: bool)
var game_is_over:= false
var game_paused:=false
var is_taking_damages:=false
var can_drive:=false
@onready var ready_go: Label = $/root/World/CanvasLayer/Texts/ReadyGo
signal start_time(game_start: bool)
var road_map_scene : String = "uid://dsn18jy5k2in8"
@onready var explosives: Node2D = $"../Explosives"


#@onready var gate: CharacterBody2D = $"../StartingGate"
#var full_command : bool
var forward_only : bool = false

#UI
#var current_life: int
@onready var life_bar: ProgressBar = $"../CanvasLayer/Board/FuelGauge"
@onready var life_label: Label = $"../CanvasLayer/Board/FuelGauge/LifeLabel"
@onready var taking_damages: Timer = $TakingDamages
@onready var speed_label: Label = $"../CanvasLayer/Board/Speed"

#VFX
@onready var car_explosion: AnimatedSprite2D = $VFX/CarExplosion
@onready var sparkles: CPUParticles2D = $VFX/Sparkles
@onready var drivin_smoke_r_2: CPUParticles2D = $RearRight/DrivinSmokeR2
@onready var drivin_smoke_l_2: CPUParticles2D = $RearLeft/DrivinSmokeL2
@onready var flash: AnimationPlayer = $CarSprite/Flash

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
	
	#MAIN STATS 
	acceleration = player.acceleration.get_value()
	max_speed = player.max_speed.get_value()
	dash_duration = player.dash_duration.get_value()
	display_max_speed = player.display_max_speed.get_value()
	damages = player.dmg.get_value()
	dash_dmg_bonus = player.dash_dmg_bonus.get_value()
	max_life = player.max_life.get_value()
	drift_turn_bonus = player.drift_turn_bonus.get_value()
	
	
	rear_left_burn_anim.hide()
	rear_right_burn_anim.hide()
	##TEST
	#WeaponsManager.test_weapons()
	
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.boost_gauge_is_full.connect(_on_boost_full)
	SignalManager.start_autopilot_transition.connect(_on_autopilot_transition_start)
	SignalManager.end_autopilot_transition.connect(_on_exit_transition)
	SignalManager.run_ended.connect(_on_run_ended)
	#gate.full_command.connect(_on_full_command)
	#gate.forward_only.connect(_on_forward_only)
	#gate.run_ended.connect(_on_run_ended)
	
	#DRIVING
	
	max_backward_speed = roundi(max_speed * 0.8)
	
	
	friction = player.friction
	turn_speed = player.turn_speed
	velocity_floor = player.velocity_floor
	burnout_boost = player.burnout_boost
	

	#DRIFT
	drift_grip = player.drift_grip
	normal_grip = player.normal_grip
	max_drift_damping = player.max_drift_damping
	min_drift_speed = player.min_drift_speed
	snap_grip = player.snap_grip
	snap_speed = player.snap_speed
	current_grip = normal_grip
	drifting = false
	player.drifting = drifting

	
	#SKIDS
	skid_spacing = player.skid_spacing
	skid_lifetime = player.skid_lifetime
	skid_fade_speed = player.skid_fade_speed
	

	#AUDIO
	start_engine_sound = player.start_engine_Sound
	dmg_players = [dmg_sfx, dmg_sfx_2, dmg_sfx_3]
	
	#VFX
	car_sprite.texture = player.car_sprite
	if TimeManager.current_day == 1 : 
		player.current_life = int(max_life)
		#print("ready day 1: ",current_life)
		
	#else : 
		#current_life = StatsManager.current_life
		#print("ready day >1: ",current_life)
	life_bar.max_value = max_life
	life_bar.value = player.current_life
	life_label.text = str(player.current_life) + "/" + str(int(player.max_life.get_value()))
	
	if visible:
		ready_go.show()
		ready_go.text = "READY ?"
		start_engine.play()

func _process(_delta: float) -> void:
	if !game_paused:
		speed_label.text  = str(roundi(velocity.length()/player.max_speed.get_value() * player.display_max_speed.get_value()))
		life_label.text = str(player.current_life) + "/" + str(int(player.max_life.get_value()))
	#update_stats()

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
		
		
		if velocity.length() > 10:
			is_invincible = true
			#car_sprite.self_modulate = Color.CHARTREUSE
		else:
			is_invincible = false
			#car_sprite.self_modulate = Color.WHITE

		
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
			steer *= drift_turn_bonus

		rotation += steer * turn_speed * steer_factor * delta

		
		var forward_velocity := forward * velocity.dot(forward)
		var lateral_velocity := lateral * velocity.dot(lateral)

		# ----------------- SLIDE -----------------
		var slip_angle := 0.0
		if velocity.length() > 10:
			slip_angle = abs(velocity.angle_to(forward)) / (PI / 2)
			slip_angle = clamp(slip_angle, 0.0, 1.0)


		# ----------------- DAMPING -----------------
		if drifting and forward_velocity.length() > min_drift_speed:
			var damping : float 
			var forward_damp : float = 1
			if abs(steer) > 0.05 :
				damping = lerp(0.0, max_drift_damping, slip_angle)
				forward_damp = 1
			else: 
				forward_damp = 0.99

			forward_velocity *= (1.0 - damping * delta) * forward_damp

		# ----------------- GRIP -----------------
		if drifting:
			current_grip = drift_grip
		elif was_drifting:
			# SNAP d’adhérence
			current_grip = lerp(current_grip, snap_grip, snap_speed * delta)
		else:
			current_grip = lerp(current_grip, normal_grip, 4.0 * delta)

		lateral_velocity = lateral_velocity.lerp(Vector2.ZERO, current_grip)

		velocity = forward_velocity + lateral_velocity

		was_drifting = drifting
		
		
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
					drifting = false
		
		# ----------------- SKIDS -----------------
		if drifting and not drifting_last_frame:
			start_skid()


		if drifting:
			var left_wheel := rear_left.global_position
			var right_wheel := rear_right.global_position

			if last_left_pos == Vector2.ZERO:
				left_line.add_point(left_wheel)
				left_border.add_point(left_wheel)
				
				right_line.add_point(right_wheel)
				right_border.add_point(right_wheel)
				
				last_left_pos = left_wheel
				last_right_pos = right_wheel
			else:
				if left_wheel.distance_to(last_left_pos) > skid_spacing:
					left_line.add_point(left_wheel)
					left_border.add_point(left_wheel)
					last_left_pos = left_wheel

				if right_wheel.distance_to(last_right_pos) > skid_spacing:
					right_line.add_point(right_wheel)
					right_border.add_point(right_wheel)
					last_right_pos = right_wheel
		
		if not drifting and drifting_last_frame:
			fade_and_destroy(left_line,left_border)
			fade_and_destroy(right_line,right_border)

			left_line = null
			left_border = null
			right_line = null
			right_border = null

		drifting_last_frame = drifting

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
	
func start_skid() -> void:
	if !game_paused:
		drift_sfx.play()
		
		var left_pair : Array = create_skid_line()
		var right_pair : Array = create_skid_line()

		left_line   = left_pair[0]   # ligne noire
		left_border = left_pair[1]   # bordure blanche

		right_line   = right_pair[0]
		right_border = right_pair[1]

		skid_parent.add_child(left_border)
		skid_parent.add_child(left_line)
		skid_parent.add_child(right_border)
		skid_parent.add_child(right_line)

		last_left_pos  = Vector2.ZERO
		last_right_pos = Vector2.ZERO
		last_right_pos = Vector2.ZERO

func create_skid_line() -> Array:
	var border := Line2D.new()
	border.width = 10
	border.default_color = Color(1, 1, 1, 0.8)
	border.antialiased = true
	border.z_index = -10 
	
	var line := Line2D.new()
	line.width = 6
	line.default_color = Color(0, 0, 0, 1.0)
	line.antialiased = true
	line.z_index = -9
	return [line,border]

func fade_and_destroy(line: Line2D, border : Line2D) -> void:
	if !game_paused:
		drift_sfx.stop()
		if line == null:
			return

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(line,   "default_color:a", 0.0, skid_lifetime)
		tween.tween_property(border, "default_color:a", 0.0, skid_lifetime)
		tween.set_parallel(false)
		tween.tween_callback(line.queue_free)
		tween.tween_callback(border.queue_free)

func get_rear_center() -> Vector2:
	return (rear_left.global_position + rear_right.global_position) * 0.5

func _on_game_paused(game_on_pause :bool) -> void:
	game_paused = game_on_pause

func get_damages_from_mob(damages_on_player: int) -> void:
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
	WeaponsManager.unload()
	end_dash()
	car_sprite.hide()
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

func _on_body_parts_area_entered(area: Area2D) -> void:
	if !game_paused and velocity.length() >= velocity_floor:
		if area.is_in_group("ennemies") and "get_damages" in area:
			area.get_damages(roundi(player.dmg.get_value()))
		else : return

func _on_start_engine_finished() -> void:
	can_drive = true
	emit_signal("start_time", can_drive)
	WeaponsManager.activate_weapons(true)
	#empty_explosives()
	ready_go.text = "GO !"
	await get_tree().create_timer(SceneManager.ready_go_timer).timeout
	ready_go.hide()

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
	emit_signal("dashing")
	can_dash = false

	Engine.time_scale = 0.08
	await get_tree().create_timer(0.08 * 0.08).timeout
	Engine.time_scale = 1.0

	camera_2d.screen_shake(12, 0.4)

	var mod_dmg := Modifier.new(dash_dmg_bonus, Modifier.Type.PERCENT_MULT, "dmg_dash_bonus", player.dash_duration.get_value())
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

func _on_boost_full() -> void:
	can_dash = true

func damages_sfx()-> void : 
	if game_paused or game_is_over:
		return
	for dmg_player in dmg_players:
		if !dmg_player.playing:
			dmg_player.play()
			return

func _on_run_ended() -> void:
	pass
	#StatsManager.current_life = player.current_life
	#print("run ended : ",current_life)

func play_drivin_smokes() -> void : 
	if game_paused or game_is_over:
		return
	drivin_smoke_r_2.emitting = true
	drivin_smoke_l_2.emitting = true

func get_drift_factor() -> float:
	if velocity.length() < 10.0 or !drifting:
		return 0.0
	var forward := Vector2.RIGHT.rotated(rotation)
	var angle : float = forward.angle_to(velocity.normalized())
	var factor : float = clamp(angle / deg_to_rad(20.0), -1.0, 1.0)
	return factor

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
	SceneManager.load_level(road_map_scene)
