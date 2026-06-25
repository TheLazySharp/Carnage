extends Node2D

@onready var skid_parent: Node2D = get_node("/root/World/SkidMarks")
@onready var rear_left: Marker2D = $"../RearLeft"
@onready var rear_right: Marker2D = $"../RearRight"

@onready var drift_label: Label = $"../../CanvasLayer/HUD/DRIFT"
@onready var total_label: Label = $"../../CanvasLayer/HUD/TotalDrift"
@onready var drift_multi_label: Label = $"../../CanvasLayer/HUD/DriftMulti"

var game_paused : bool = false

var car : CharacterBody2D
var player : CarData

var drifting : bool = false
var was_drifting : bool = false
var drifting_last_frame : bool = false

var current_grip : float
var drift_grip : float
var normal_grip : float
var max_drift_damping : float
var min_drift_speed : float
var snap_grip : float
var snap_speed : float

#SKID
var skid_spacing : float
var skid_lifetime : float
var skid_fade_speed : float
var left_line: Line2D = null
var right_line: Line2D = null
var left_border: Line2D = null
var right_border: Line2D = null
var last_left_pos := Vector2.ZERO
var last_right_pos := Vector2.ZERO

# REAR LIGHT TRAILS
var left_trail: Line2D = null
var right_trail: Line2D = null
var last_left_trail_pos := Vector2.ZERO
var last_right_trail_pos := Vector2.ZERO
var trail_spacing : float = 2.0
var trail_lifetime : float = 0.3

#AUDIO
@onready var drift_sfx: AudioStreamPlayer2D = $DriftSfx

#DRIFT BONUS -> increase car DMG
var drift_bonus : int
var total_drift_points : int
var drift_points_multi : float
var car_dmg_mod : Modifier


func _ready() -> void:
	SignalManager.connect("wall_collision",_on_wall_collision)
	SignalManager.connect("game_paused",_on_game_paused)
	SignalManager.connect("game_is_over",_on_game_over)
	drift_bonus = 0
	total_drift_points = StatsManager.total_drift
	drift_points_multi = snappedf(total_drift_points * 0.0001,0.01) #change in the animation tween callback below
	drift_label.text = str(get_drift_bonus_points())
	total_label.text = str(total_drift_points) + " pts"
	drift_multi_label.text = " DMG + " + str(drift_points_multi)


func init_drift(car_node : CharacterBody2D, data : CarData, p_rear_left : Marker2D, p_rear_right : Marker2D) -> void : 
	car = car_node
	player = data
	rear_left = p_rear_left
	rear_right = p_rear_right

	drift_grip = player.drift_grip
	normal_grip = player.normal_grip
	max_drift_damping = player.max_drift_damping
	min_drift_speed = player.min_drift_speed
	snap_grip = player.snap_grip
	snap_speed = player.snap_speed
	current_grip = normal_grip

	skid_spacing = player.skid_spacing
	skid_lifetime = player.skid_lifetime
	skid_fade_speed = player.skid_fade_speed
	
	car_dmg_mod = Modifier.new(int(drift_points_multi),Modifier.Type.FLAT,"drift manager bonus")
	player.dmg.add_modifier(car_dmg_mod)
	#print("car dmg : ", player.dmg.get_value())

func _process(_delta: float) -> void:
	drift_label.text = str(get_drift_bonus_points())

func update_drift(delta : float, input_drifting : bool, p_forward_velocity : Vector2, p_lateral_velocity : Vector2, p_forward : Vector2, p_velocity : Vector2) -> Vector2:
	drifting = input_drifting
	
	var forward_velocity : Vector2 = p_forward_velocity
	var lateral_velocity : Vector2 = p_lateral_velocity
	
		# ------------------- SLIDE & DAMPING
	if drifting and forward_velocity.length() > min_drift_speed:
		var slip_angle := 0.0
		if p_velocity.length() > 10:
			slip_angle = clamp(abs(p_velocity.angle_to(p_forward)) / (PI / 2), 0.0, 1.0)
			
			var steer : float = get_steer_input()
			var damping : float 
			var forward_damp : float = 1
			if abs(steer) > 0.05 :
				damping = lerp(0.0, max_drift_damping, slip_angle)
				forward_damp = 1
			else: 
				forward_damp = 0.99
				damping = 0
			
			forward_velocity *= (1.0 - damping * delta) * forward_damp

		# ----------------- GRIP -----------------
	if drifting:
		current_grip = drift_grip
	elif was_drifting:
		current_grip = lerp(current_grip, snap_grip, snap_speed * delta)
	else:
		current_grip = lerp(current_grip, normal_grip, 4.0 * delta)

	lateral_velocity = lateral_velocity.lerp(Vector2.ZERO, current_grip)


		# ----------------- SKIDS -----------------
	if drifting and not drifting_last_frame:
		start_skid()

	if drifting:
		update_skid_points()

	if not drifting and drifting_last_frame:
		end_skid()

	was_drifting = drifting
	drifting_last_frame = drifting
	
	player.drifting = drifting
	
	return forward_velocity + lateral_velocity

func start_skid() -> void:
	drift_sfx.play()
	
	var left_pair : Array = create_skid_line()
	var right_pair : Array = create_skid_line()

	left_line   = left_pair[0]
	left_border = left_pair[1]

	right_line   = right_pair[0]
	right_border = right_pair[1]

	skid_parent.add_child(left_border)
	skid_parent.add_child(left_line)
	skid_parent.add_child(right_border)
	skid_parent.add_child(right_line)

	last_left_pos  = Vector2.ZERO
	last_right_pos = Vector2.ZERO
	
	left_trail  = create_trail_line()
	right_trail = create_trail_line()
	skid_parent.add_child(left_trail)
	skid_parent.add_child(right_trail)
	last_left_trail_pos  = Vector2.ZERO
	last_right_trail_pos = Vector2.ZERO

func create_skid_line() -> Array:
	var border : Line2D = Line2D.new()
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

func create_trail_line() -> Line2D:
	var trail := Line2D.new()
	trail.width = 2
	trail.default_color = Color(3.0, 0.1, 0.1, 0.9)
	trail.antialiased = true
	trail.z_index = 2
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	return trail

func update_skid_points() -> void : 
	var left_wheel : Vector2 = rear_left.global_position
	var right_wheel : Vector2 = rear_right.global_position

	var car_right : Vector2 = Vector2.RIGHT.rotated(car.rotation)
	var trail_offset : float = 6.0

	var left_wheel_trail : Vector2 = rear_left.global_position  + car_right * trail_offset
	var right_wheel_trail : Vector2 = rear_right.global_position - car_right * trail_offset

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
			
# LIGHT TRAILS
	if last_left_trail_pos == Vector2.ZERO:
		left_trail.add_point(left_wheel_trail)
		right_trail.add_point(right_wheel_trail)
		last_left_trail_pos  = left_wheel_trail
		last_right_trail_pos = right_wheel_trail
	else:
		if left_wheel_trail.distance_to(last_left_trail_pos) > trail_spacing:
			left_trail.add_point(left_wheel_trail)
			last_left_trail_pos = left_wheel_trail
		if right_wheel_trail.distance_to(last_right_trail_pos) > trail_spacing:
			right_trail.add_point(right_wheel_trail)
			last_right_trail_pos = right_wheel_trail

	var max_trail_points : int = 40
	if left_trail.get_point_count() > max_trail_points:
		left_trail.remove_point(0)
	if right_trail.get_point_count() > max_trail_points:
		right_trail.remove_point(0)


func fade_and_destroy(line: Line2D, border : Line2D) -> void:
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
	
func fade_trail(trail: Line2D) -> void:
	if trail == null:
		return
	var tween := create_tween()
	tween.tween_property(trail, "default_color:a", 0.0, trail_lifetime)
	tween.tween_callback(trail.queue_free)

func end_skid() -> void : 
	total_drift_points += drift_bonus
	StatsManager.total_drift += drift_bonus
	animation_score_to_total()
	
	fade_and_destroy(left_line,left_border)
	fade_and_destroy(right_line,right_border)

	left_line = null
	left_border = null
	right_line = null
	right_border = null

	fade_and_destroy(left_line, left_border)
	fade_and_destroy(right_line, right_border)
	fade_trail(left_trail)
	fade_trail(right_trail)
	
	left_line = null
	left_border = null
	right_line = null
	right_border = null
	left_trail = null
	right_trail = null

func force_stop_skid() -> void : 
	if left_line != null:
		fade_and_destroy(left_line, left_border)
		left_line = null
		left_border = null
	if right_line != null:
		fade_and_destroy(right_line, right_border)
		right_line = null
		right_border = null
		
	if left_trail != null:
		fade_trail(left_trail)
		left_trail = null
	if right_trail != null:
		fade_trail(right_trail)
		right_trail = null
		
	drifting = false
	drifting_last_frame = false
	was_drifting = false



func get_drift_factor() -> float:
	if car.velocity.length() < 10.0 or !drifting:
		return 0.0
	var forward : Vector2 = Vector2.RIGHT.rotated(car.rotation)
	var angle : float = forward.angle_to(car.velocity.normalized())
	return clamp(angle / deg_to_rad(20.0), -1.0, 1.0)

func is_drifting() -> bool:
	return drifting

func get_steer_input() -> float:
	return Input.get_action_strength("move_right") - Input.get_action_strength("move_left")

func get_drift_bonus_points() -> int :
	if drifting: 
		if !game_paused:
			var forward : Vector2 = Vector2.RIGHT.rotated(car.rotation)
			var angle : float = abs(forward.angle_to(car.velocity.normalized()))
			var angle_factor: float = clamp(angle / (PI / 2), 0.0, 1.0)
			drift_bonus += int(car.velocity.length() * 0.1 * angle_factor)
		else : 
			drift_bonus = drift_bonus
	else : 
		drift_bonus = 0
	return drift_bonus

func animation_score_to_total() -> void : 
	if drift_bonus <= 0 : 
		return
	
	var fly_label : Label = Label.new()
	fly_label.text = str(drift_bonus)
	fly_label.add_theme_font_override("font",FontManager.FONTS[FontManager.types.UX][0])
	fly_label.add_theme_font_size_override("font_size",FontManager.FONTS[FontManager.types.UX][1])
	fly_label.add_theme_color_override("font_color",FontManager.dark_yellow)
	
	fly_label.add_theme_color_override("font_outline_color",Color.BLACK)
	fly_label.add_theme_constant_override("outline_size",FontManager.UX_outline)
	drift_label.get_parent().add_child(fly_label)
	fly_label.position = Vector2(3.0,66.0)
	
	var tween : Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(fly_label, "position", Vector2(500.0, 740.0), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(fly_label, "theme_override_font_sizes/font_size", 24, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(fly_label, "modulate:a", 0.0, 1.0)
	
	fly_label.scale = Vector2(1.8, 1.8)
	tween.tween_property(fly_label, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	tween.set_parallel(false)
	tween.tween_callback(fly_label.queue_free)
	
	tween.tween_callback(func() -> void:
		drift_points_multi = snappedf(total_drift_points * 0.0001,0.01) # change in ready also
		total_label.text = str(total_drift_points) + " pts"
		drift_multi_label.text = "DMG + " + str(drift_points_multi)
		
		player.dmg.remove_modifier(car_dmg_mod)
		car_dmg_mod = Modifier.new(int(drift_points_multi),Modifier.Type.FLAT,"drift manager bonus")
		player.dmg.add_modifier(car_dmg_mod)
		#print("car dmg : ", player.dmg.get_value())
		
		var flash_tween : Tween = create_tween()
		flash_tween.tween_method(func(c: Color) -> void: 
			total_label.add_theme_color_override("font_color", c),
			Color.RED, FontManager.dark_yellow, 1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	)

func _on_wall_collision() -> void : 
	if drifting:
		drift_bonus = 0

func _on_game_paused(pause : bool) -> void : 
	game_paused = pause

func _on_game_over(game_is_over : bool) -> void : 
	if game_is_over :
		pass
