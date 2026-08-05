extends Camera2D

# ---- SHAKE ----
var shake_intensity : float = 0.0
var active_shake_time : float = 0.0
var shake_decay : float = 5.0
var shake_time : float = 0.0
var shake_time_speed : float = 20.0
var noise : FastNoiseLite = FastNoiseLite.new()
var shake_offset : Vector2 = Vector2.ZERO


# ---- LOOKAHEAD ----
@export var lookahead_strength : float = 80.0
@export var lookahead_speed : float = 4.0
var lookahead_offset : Vector2 = Vector2.ZERO

# ---- ZOOM IN % SPEED ----
@export var zoom_base : float = 2.0
@export var zoom_max_out : float = 1.0
@export var zoom_speed : float = 3.0
@export var speed_max : float = 600.0
var target_zoom : float = 1.0


# ---- ROLL WHEN DRIFT ----
@export var roll_max_deg : float = 10.0
@export var roll_speed : float = 20.0
var target_roll : float = 0.0

func _ready() -> void:
	zoom = Vector2(zoom_base,zoom_base)

func _physics_process(delta: float) -> void:

	if active_shake_time > 0 : 
		shake_time += delta * shake_time_speed
		active_shake_time -= delta
		shake_offset = Vector2(noise.get_noise_2d(shake_time,0) * shake_intensity,noise.get_noise_2d(0,shake_time) * shake_intensity)
		shake_intensity = max(shake_intensity - shake_decay * delta, 0)
		
	else : shake_offset = shake_offset.lerp(Vector2.ZERO, 10.5 * delta)
	
	offset = lookahead_offset + shake_offset
	
	zoom = zoom.lerp(Vector2.ONE * target_zoom,zoom_speed * delta)
	
	rotation = lerp_angle(rotation, deg_to_rad(target_roll), roll_speed * delta)

func screen_shake(intensity : int, time : float) -> void : 
	randomize()
	noise.seed = randi()
	noise.frequency = 2.0
	shake_intensity = intensity
	active_shake_time = time
	shake_time = 0.0
	
func update_lookahead(velocity: Vector2) -> void:
	if velocity.length() > 10.0:
		lookahead_offset = lookahead_offset.lerp(velocity.normalized() * lookahead_strength,lookahead_speed * get_physics_process_delta_time())
	else:
		lookahead_offset = lookahead_offset.lerp(Vector2.ZERO, lookahead_speed * get_physics_process_delta_time())


func update_zoom(speed: float) -> void:
	var t : float = clamp(speed / speed_max, 0.0, 1.0)
	target_zoom = lerp(zoom_base, zoom_max_out, t)


func update_roll(drift_factor: float) -> void:
	target_roll = drift_factor * roll_max_deg
