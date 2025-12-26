extends CharacterBody2D

@export var acceleration := 950.0
@export var max_speed := 720.0
@export var friction := 500.0
@export var turn_speed := 3.2

# Drift tuning
@export var drift_grip := 0.015
@export var normal_grip := 0.18
@export var drift_turn_bonus := 3.2

@export var max_drift_damping := 3.5
@export var min_drift_speed := 150.0

@export var snap_grip := 0.75
@export var snap_speed := 8.0

var current_grip := normal_grip
var was_drifting := false

#SKID

@export var skid_marks_path: NodePath

@export var skid_spacing := 8.0
@export var skid_lifetime := 2.5
@export var skid_fade_speed := 1.5

@onready var skid_parent: Node2D = get_node(skid_marks_path)

@onready var rear_left: Marker2D = $RearLeft
@onready var rear_right: Marker2D = $RearRight


var left_line: Line2D = null
var right_line: Line2D = null

var last_left_pos := Vector2.ZERO
var last_right_pos := Vector2.ZERO

var drifting_last_frame := false

signal game_over(game_is_over: bool)
var game_is_over:= false

@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:=false

#UI

var max_life: int
var current_life: int

@onready var life_bar: ProgressBar = $"../CanvasLayer/Board/Fuel/FuelGauge"

@export var damages_text: PackedScene
#@onready var damages_text_pos = get_node("MarkerDamages")
@onready var taking_damages: Timer = $TakingDamages

var is_taking_damages:=false

@onready var speed_label: Label = $"../CanvasLayer/Board/Speed"
var display_max_speed : int = 250

func _ready() -> void:
	gm_scene.game_paused.connect(_on_game_paused)
	max_life = StatsManager.max_life
	current_life = max_life
	life_bar.max_value = max_life
	life_bar.value = current_life

func _process(_delta: float) -> void:
	if !game_paused:
		speed_label.text  = str(roundi(velocity.length()/max_speed * display_max_speed))

func _physics_process(delta):
	if not game_paused:
		var forward := Vector2.RIGHT.rotated(rotation)
		var lateral := forward.rotated(PI / 2)

		# ----------------- INPUT -----------------
		var throttle := Input.get_action_strength("accelerate") - Input.get_action_strength("brake")
		var steer := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		var drifting := Input.is_action_pressed("drift")

		# ----------------- ACCELERATION -----------------
		if throttle != 0:
			velocity += forward * throttle * acceleration * delta
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

		velocity = velocity.limit_length(max_speed)

		# ----------------- ROTATION -----------------
		var speed := velocity.dot(forward)
		var steer_factor = clamp(abs(speed) / max_speed, 0.25, 1.0)

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
			var damping = lerp(0.0, max_drift_damping, slip_angle)
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

		# --- GESTION DES TRACES ---
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


func start_skid():
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


func _on_collect_zone_entered(area: Area2D) -> void:
	if area.is_in_group("collectables") and !game_is_over:
		XPManager.get_xp(1)

func _on_game_paused(game_on_pause) -> void:
	game_paused = game_on_pause
	
#func take_damages(damages: int) -> void:
	#if not game_paused and !game_is_over :
		#is_taking_damages = true
		#current_life -= damages
		#life_bar.value = current_life
		##display_damages(damages)
		#print(str(current_life))
		##animation_player.play("beaver_animations/flash")
		#taking_damages.start()
		#
		#if current_life <=0:
			#current_life = 0
			#play_death()
			#return
			#
		#if is_taking_damages:return
		
func play_death() -> void:
	is_taking_damages = false
	#animation_player.stop()
	game_is_over = true
	#animated_sprite.hide()
	await get_tree().create_timer(1).timeout
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
#func _on_taking_damages_timeout() -> void:
	#is_taking_damages = false
	##animation_player.stop()


#func _on_body_parts_collision(body: Node2D) -> void:
	##var dmg = 5
	#if body.is_in_group("ennemies") and "get_damages" in body:
		#print("body collision with enemy")
		##body.get_damages(dmg)
		##print("body dmg = ",dmg)
	#else : return


func _on_body_parts_area_entered(area: Area2D) -> void:
	if !game_paused:
		var enemy = area.get_parent()
		var dmg = 15
		if enemy.is_in_group("ennemies") and "get_damages" in enemy:
			enemy.get_damages(dmg)
		else : return
