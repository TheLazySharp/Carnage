extends CharacterBody2D


@export var steering_angle = 15
@export var engine_power = 900
@export var friction = -55
@export var air_drag = -0.06
@export var braking = -450
@export var max_speed_reverse = 250
@export var slip_speed = 400
@export var traction_fast = 2.5
@export var traction_slow = 10

var wheel_base = 65
var acceleration = Vector2.ZERO
var steer_direction : float

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	acceleration = Vector2.ZERO
	process_inputs()
	apply_friction(delta)
	calculate_steering(delta)
	velocity += acceleration * delta
	move_and_slide()


func process_inputs()-> void:
	var turn = Input.get_axis("move_left","move_right")
	steer_direction = turn * deg_to_rad(steering_angle)
	
	if Input.is_action_pressed("accelerate"):
		acceleration = transform.x * engine_power
		#print("acceleration : ",acceleration)
	
	if Input.is_action_pressed("brake"):
		acceleration = transform.x * braking
		#print("brake : ",acceleration)
		
	

func apply_friction(delta):
	#if acceleration == Vector2.ZERO and velocity.length() <0.1:
		#velocity = Vector2.ZERO
		#print("car stoppping")
	var friction_force = velocity * friction * delta
	var drag_force = velocity * velocity.length() * air_drag * delta
	acceleration += drag_force + friction_force
	

func calculate_steering(delta):
	var rear_wheel : Vector2 = position - transform.x * wheel_base * 0.5
	var front_wheel  : Vector2 = position + transform.x * wheel_base * 0.5
	
	rear_wheel += velocity * delta
	front_wheel += velocity.rotated(steer_direction) * delta
	
	var new_heading = rear_wheel.direction_to(front_wheel)
	
	var traction = traction_slow
	if velocity.length() > slip_speed:
		traction = traction_fast
	
	var d = new_heading.dot(velocity.normalized())
	
	if d > 0:
		velocity = lerp(velocity, new_heading * velocity.length(), traction * delta)
	
	if d < 0:
		velocity = - new_heading * min(velocity.length(), max_speed_reverse)
	
	rotation = new_heading.angle()
