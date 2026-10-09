extends Node2D
class_name BloodyEngine

var car_res : CarData
var player : SurvivorData
var game_paused : bool = false
@onready var car: CharacterBody2D = $".."
var car_sprite : Sprite2D = null
var is_dead : bool = false
@onready var blood_impact_pool: BloodImpactPool
#VFX
@export var vaccum_particles_scene : PackedScene
var vaccum_particles : CPUParticles2D = null
var absorb_until : float = 0.0
var absorb_window : float = 0.18
var tint_speed : float = 7.0
var blood_amount : float = 0.0
@export var blood_hold_time : float = 0.4
var blood_hold_timer : float = 0.0
@export var sprite_tinted : bool = false
@export var neons_activated : bool = false

signal blood_absorbed

@export var fuel_per_splat: int = 1
var max_life : float

var blood_tank_q : int = 0
var combo_multiplier : float = 1.0


func _ready() -> void:
	if GameMaster.is_debug():
		set_process(false)
		set_physics_process(false)
		return
	if GameMaster.is_debug() or SceneManager.race_mode:
		for child : Node in get_children():
			var timer : Timer = child as Timer
			if timer != null:
				timer.stop()

	blood_impact_pool= $/root/World/VFX/BloodImpactPool

	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.blood_consummed.connect(_on_car_blood_consummed)
	ItemManager.gas.connect(_on_gas_tank_picked_up)
	SignalManager.car_blood_changed.connect(_on_car_blood_changed)
	SignalManager.survivor_blood_consummed.connect(_on_survivor_blood_consummed)
	SignalManager.combo_changed.connect(_on_combo_changed)
	vaccum_particles = vaccum_particles_scene.instantiate()
	add_child(vaccum_particles)
	vaccum_particles.emitting = false

#func _input(event: InputEvent) -> void:
	#if event.is_action_pressed("test"):
		#InventoryManager.blood_tank_q +=1000
		#BloodBars.update_blood_tank()

func init_bloody_engine(p_car_res : CarData, p_sprite : Sprite2D, _dash_manager : DashManager) -> void :
	car_res = p_car_res
	car_sprite = p_sprite
	max_life = car_res.max_life.get_value()
	car_res.current_life = int(max_life)
	
	player = SurvivorsManager.on_board_survivors[0]
	init_survivor(player)
	_on_car_blood_changed(0)
	

	var mat : ShaderMaterial = car_sprite.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("blood_amount", 0.0)

func init_survivor(survivor : SurvivorData) -> void : 
	is_dead = false
	survivor.current_life = survivor.max_life
	BloodBars.update_survivor_blood()
	
func _process(delta: float) -> void:
	var absorbing : bool = (not game_paused) and (Time.get_ticks_msec() / 1000.0 < absorb_until)

	if vaccum_particles != null:
		vaccum_particles.emitting = absorbing
	
	if sprite_tinted:
		update_blood_tint(absorbing, delta)


func _physics_process(_delta: float) -> void:
	if game_paused:
		return
	var harvested: int = blood_impact_pool.harvest(car.global_position)
	if harvested > 0:
		# The combo multiplies the harvested blood
		blood_up(roundi(harvested * fuel_per_splat * combo_multiplier))
		bloody_vaccum()

func _on_game_paused(game_on_pause :bool) -> void:
	game_paused = game_on_pause

func _on_combo_changed(multiplier : float, _combo_count : int) -> void:
	combo_multiplier = multiplier

func blood_up(added_blood : int) -> void :
	SignalManager.emit_signal("car_blood_absorbed",added_blood)
	_on_car_blood_changed(added_blood)


func bloody_vaccum() -> void :
	if neons_activated:
		emit_signal("blood_absorbed")
	absorb_until = Time.get_ticks_msec() / 1000.0 + absorb_window


func update_blood_tint(absorbing : bool, delta : float) -> void:
	if car_sprite == null:
		return
	var mat : ShaderMaterial = car_sprite.material as ShaderMaterial
	if mat == null:
		return
	# Keep the target at 1.0 for a short time after each absorption,
	# so brief or intermittent absorption still reaches full tint/glow
	if absorbing:
		blood_hold_timer = blood_hold_time
	else:
		blood_hold_timer = maxf(blood_hold_timer - delta, 0.0)
	var target : float = 1.0 if blood_hold_timer > 0.0 else 0.0
	# minf() prevents overshoot if tint_speed * delta > 1.0 (lag spike)
	var new_amount : float = lerpf(blood_amount, target, minf(tint_speed * delta, 1.0))
	# Snap near the target so the lerp actually settles and stops updating the uniform
	if absf(new_amount - target) < 0.005:
		new_amount = target
	if new_amount == blood_amount:
		return
	blood_amount = new_amount
	mat.set_shader_parameter("blood_amount", blood_amount)


func _on_gas_tank_picked_up() -> void :
	blood_up(int(car_res.max_life.get_value() - car_res.current_life))

func blood_consumption(blood_q : int) -> void :
	_on_car_blood_changed(-blood_q)


#func _on_fuel_timer_timeout() -> void:
	#if game_paused :
		#return
	#blood_consumption(car_res.regular_fuel_leak)

#func _on_dash_started() -> void :
	#fuel_consumption(car_res.dash_fuel_down)


func _on_car_blood_consummed(blood_cost : int) -> void:
	blood_consumption(blood_cost)
	
func _on_survivor_blood_consummed(blood_q : int) -> void:
	_on_survivor_blood_changed(- blood_q, player.max_life)
	
func refresh_display() -> void:
	BloodBars.update_car_blood()
	BloodBars.update_survivor_blood()

func _on_car_blood_changed(p_life_change : int) -> void:
	if p_life_change >= 0:
		if car_res.current_life + p_life_change > car_res.max_life.get_value():
			var transfered_blood : int = car_res.current_life + p_life_change - int(car_res.max_life.get_value())
			car_res.current_life = int(car_res.max_life.get_value())
			_on_survivor_blood_changed(transfered_blood, player.max_life)
		else : 
			car_res.current_life += p_life_change
		
		
	else :
		var blood_excedent : int = absi(p_life_change) - car_res.current_life
		if blood_excedent > 0 :
			car_res.current_life += p_life_change
			if car_res.current_life < 0:
				car_res.current_life = 0
			_on_survivor_blood_changed(- blood_excedent, player.max_life)
	
		else : 
			car_res.current_life += p_life_change

	if car:
		BloodBars.update_car_blood()


func _on_survivor_blood_changed(p_life_change : int, _p_max_life : int) -> void:
	if is_dead:
		return
	var new_life : int = player.current_life + p_life_change
	if new_life > player.max_life:
		InventoryManager.blood_tank_q += new_life - player.max_life
		player.current_life = player.max_life
		BloodBars.update_blood_tank()
	elif new_life <= 0:
		player.current_life = 0
		is_dead = true
	else:
		player.current_life = new_life
	BloodBars.update_survivor_blood()
	if is_dead:
		car.on_death()
	
