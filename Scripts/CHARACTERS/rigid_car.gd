extends CharacterBody2D

var player : CarData

#CAR DATA
var acceleration : float
var max_speed : int
var friction : float
var turn_speed : float
var drift_grip : float
var normal_grip : float
var drift_turn_bonus : float
var max_drift_damping : float
var min_drift_speed : float
var snap_grip : float
var snap_speed : float
var current_grip : float
var was_drifting : bool = false
var skid_spacing : float
var skid_lifetime : float
var skid_fade_speed : float
var max_life : int
var dmg : int
var velocity_floor : int
var display_max_speed : int
var start_engine_sound : AudioStreamMP3
@onready var car_sprite: Sprite2D = $CarSprite


#SKID
@export var skid_marks_path: NodePath
@onready var skid_parent: Node2D = get_node(skid_marks_path)
@onready var rear_left: Marker2D = $RearLeft
@onready var rear_right: Marker2D = $RearRight
var left_line: Line2D = null
var right_line: Line2D = null
var last_left_pos := Vector2.ZERO
var last_right_pos := Vector2.ZERO

#DRIFT
var drifting_last_frame := false

#GAME
signal game_over(game_is_over: bool)
var game_is_over:= false
@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:=false
var is_taking_damages:=false
var can_drive:=false
@onready var ready_go: Label = $/root/World/CanvasLayer/Texts/ReadyGo
signal start_time(game_start: bool)

@onready var gate: CharacterBody2D = $"../StartingGate"
#var full_command : bool
var forward_only : bool

#UI
var current_life: int
@onready var life_bar: ProgressBar = $"../CanvasLayer/Board/Fuel/FuelGauge"
@onready var life_label: Label = $"../CanvasLayer/Board/Fuel/LifeLabel"
@export var damages_text: PackedScene
#@onready var damages_text_pos = get_node("MarkerDamages")
@onready var taking_damages: Timer = $TakingDamages
@onready var speed_label: Label = $"../CanvasLayer/Board/Speed"
@onready var car_explosion: AnimatedSprite2D = $VFX/CarExplosion
@onready var start_engine: AudioStreamPlayer = $Audio/StartEngine


func _ready() -> void:
	player = CarManager.selected_car
	gm_scene.game_paused.connect(_on_game_paused)
	gate.full_command.connect(_on_full_command)
	gate.forward_only.connect(_on_forward_only)
	
	#DRIVING
	acceleration = player.acceleration + player.carbon_lvl * 10 - player.shield_lvl * 5
	max_speed = player.max_speed + player.engine_lvl * 10
	friction = player.friction
	turn_speed = player.turn_speed
	velocity_floor = player.velocity_floor

	#DRIFT
	drift_grip = player.drift_grip
	normal_grip = player.normal_grip
	drift_turn_bonus = player.drift_turn_bonus
	max_drift_damping = player.max_drift_damping
	min_drift_speed = player.min_drift_speed
	snap_grip = player.snap_grip
	snap_speed = player.snap_speed
	current_grip = normal_grip
	
	#SKIDS
	skid_spacing = player.skid_spacing
	skid_lifetime = player.skid_lifetime
	skid_fade_speed = player.skid_fade_speed
	
	#STATS
	max_life = player.max_life
	display_max_speed = player.display_max_speed
	dmg = player.dmg
	
	#AUDIO
	start_engine_sound = player.start_engine_Sound
	start_engine.stream  = start_engine_sound
	
	#VFX
	car_sprite.texture = player.car_sprite

	
	current_life = max_life
	life_bar.max_value = max_life
	life_bar.value = current_life
	life_label.text = str(current_life) + "/" + str(max_life)
	print(rotation)
	if visible:
		ready_go.show()
		ready_go.text = "READY ?"
		start_engine.play()

func _process(_delta: float) -> void:
	if !game_paused:
		speed_label.text  = str(roundi(velocity.length()/max_speed * display_max_speed))
		life_label.text = str(current_life) + "/" + str(max_life)
	#update_stats()

func _physics_process(delta : float) -> void:
	if not game_paused and can_drive:
		var forward := Vector2.RIGHT.rotated(rotation)
		var lateral := forward.rotated(PI / 2)

		# ----------------- INPUT -----------------
		var throttle := Input.get_action_strength("accelerate") - Input.get_action_strength("brake")
		var steer := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		var drifting := Input.is_action_pressed("drift")
		
		if forward_only:
			throttle = Input.get_action_strength("accelerate")
			steer = 0
			drifting = false
		
		# ----------------- ACCELERATION -----------------
		if throttle != 0:
			velocity += forward * throttle * acceleration * delta
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

		velocity = velocity.limit_length(max_speed)

		# ----------------- ROTATION -----------------
		var speed := velocity.dot(forward)
		var steer_factor : float = clamp(abs(speed) / max_speed, 0.25, 1.0)

		if drifting:
			steer *= drift_turn_bonus

		rotation += steer * turn_speed * steer_factor * delta

		# ----------------- DECOMPOSITION -----------------
		var forward_velocity := forward * velocity.dot(forward)
		var lateral_velocity := lateral * velocity.dot(lateral)

		# ----------------- ANGLE DE GLISSE -----------------
		var slip_angle := 0.0
		if velocity.length() > 10:
			slip_angle = abs(velocity.angle_to(forward)) / (PI / 2)
			slip_angle = clamp(slip_angle, 0.0, 1.0)


		# ----------------- DAMPING NFSU2 -----------------
		if drifting and abs(steer) > 0.05 and forward_velocity.length() > min_drift_speed:
			var damping : float = lerp(0.0, max_drift_damping, slip_angle)
			forward_velocity *= (1.0 - damping * delta)

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
		move_and_slide()

		#SKIDS
		if drifting and not drifting_last_frame:
			start_skid()


		if drifting:
			var left_wheel := rear_left.global_position
			var right_wheel := rear_right.global_position

			if last_left_pos == Vector2.ZERO:
				left_line.add_point(left_wheel)
				right_line.add_point(right_wheel)
				last_left_pos = left_wheel
				last_right_pos = right_wheel
			else:
				if left_wheel.distance_to(last_left_pos) > skid_spacing:
					left_line.add_point(left_wheel)
					last_left_pos = left_wheel

				if right_wheel.distance_to(last_right_pos) > skid_spacing:
					right_line.add_point(right_wheel)
					last_right_pos = right_wheel
		
		if not drifting and drifting_last_frame:
			fade_and_destroy(left_line)
			fade_and_destroy(right_line)

			left_line = null
			right_line = null

		drifting_last_frame = drifting


func start_skid() -> void:
	if !game_paused:
		left_line = create_skid_line()
		right_line = create_skid_line()

		skid_parent.add_child(left_line)
		skid_parent.add_child(right_line)

		last_left_pos = Vector2.ZERO
		last_right_pos = Vector2.ZERO


func create_skid_line() -> Line2D:
	var line := Line2D.new()
	line.width = 6
	line.default_color = Color(0, 0, 0, 0.6)
	line.antialiased = true
	line.z_index = -10
	return line



func fade_and_destroy(line: Line2D) -> void:
	if !game_paused:
		if line == null:
			return

		var tween := create_tween()
		tween.tween_property(
			line,
			"default_color:a",
			0.0,
			skid_lifetime
		)
		tween.tween_callback(line.queue_free)


func get_rear_center() -> Vector2:
	return (rear_left.global_position + rear_right.global_position) * 0.5


func _on_game_paused(game_on_pause :bool) -> void:
	game_paused = game_on_pause
	
func take_damages(damages: int) -> void:
	if not game_paused and !game_is_over and velocity.length() < velocity_floor:
		is_taking_damages = true
		current_life -= damages
		life_bar.value = current_life
		#display_damages(damages)
		print(str(current_life))
		#animation_player.play("beaver_animations/flash")
		taking_damages.start()
		
		if current_life <=0:
			current_life = 0
			play_death()
			return
			
		if is_taking_damages:return
		
func play_death() -> void:
	is_taking_damages = false
	car_sprite.hide()
	car_explosion.play("Explosion")
	game_is_over = true
	#animated_sprite.hide()
	await get_tree().create_timer(3).timeout
	emit_signal("game_over", game_is_over)
	
	
#func display_damages(_damages)-> void:
	#if !game_is_over:
		#pass
		##var text = damages_text.instantiate()
		##var text_offsetX = RandomNumberGenerator.new().randf_range(-10,10)
		##var text_offsetY = RandomNumberGenerator.new().randf_range(-10,0)
		##text.this_label_text = "- " +str(damages)
		##add_child(text)
		##text.global_position = Vector2(damages_text_pos.global_position.x + text_offsetX, damages_text_pos.global_position.y + text_offsetY)
#
#
func _on_taking_damages_timeout() -> void:
	is_taking_damages = false
	#animation_player.stop()


#func _on_body_parts_collision(body: Node2D) -> void:
	##var dmg = 5
	#if body.is_in_group("ennemies") and "get_damages" in body:
		#print("body collision with enemy")
		##body.get_damages(dmg)
		##print("body dmg = ",dmg)
	#else : return


func _on_body_parts_area_entered(area: Area2D) -> void:
	if !game_paused and velocity.length() >= velocity_floor:
		var enemy : Enemy = area.get_parent()
		if enemy.is_in_group("ennemies") and "get_damages" in enemy:
			enemy.get_damages(dmg)
		else : return


func _on_start_engine_finished() -> void:
	can_drive = true
	emit_signal("start_time", can_drive)
	ready_go.text = "GO !"
	await get_tree().create_timer(2).timeout
	ready_go.hide()

func _on_full_command(full_command : bool) -> void:
	if !full_command:
		can_drive = false
		
func _on_forward_only(car_only_forward : bool) -> void:
	forward_only = car_only_forward
