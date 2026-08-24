extends Node2D
class_name BloodyEngine

var player : CarData
var game_paused : bool = false
@onready var car: CharacterBody2D = $".."
var car_sprite : Sprite2D = null

@onready var blood_impact_pool: BloodImpactPool = $/root/World/VFX/BloodImpactPool
#VFX
@export var vaccum_particles_scene : PackedScene
var vaccum_particles : CPUParticles2D = null
var absorb_until : float = 0.0
var absorb_window : float = 0.18
var tint_speed : float = 7.0

#FUEL
@onready var fuel_bar: ProgressBar = $"/root/World/CanvasLayer/HUD/FuelGauge"
@onready var fuel_label: Label = $"/root/World/CanvasLayer/HUD/FuelGauge/FuelLabel"
@export var fuel_per_splat: int = 1
var max_fuel : float


func _ready() -> void:
	if GameMaster.is_debug():
		set_process(false)
		set_physics_process(false)
		for child : Node in get_children():
			var timer : Timer = child as Timer
			if timer != null:
				timer.stop()
		return
		
	SignalManager.game_paused.connect(_on_game_paused)
	ItemManager.gas.connect(_on_gas_tank_picked_up)

	vaccum_particles = vaccum_particles_scene.instantiate()
	add_child(vaccum_particles)
	vaccum_particles.emitting = false


func init_bloody_engine(p_player : CarData, p_sprite : Sprite2D, dash_manager : DashManager) -> void :
	player = p_player
	car_sprite = p_sprite
	max_fuel = player.max_fuel.get_value()
	player.current_fuel = int(max_fuel)
	fuel_bar.max_value = max_fuel
	fuel_bar.value = player.max_fuel.get_value()
	# Fuel is only charged once, when the boost ignites
	dash_manager.dash_started.connect(_on_dash_started)

	var mat : ShaderMaterial = car_sprite.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("blood_amount", 0.0)

func _process(delta: float) -> void:
	fuel_label.text = str(player.current_fuel) + "/" + str(int(player.max_fuel.get_value()))

	var absorbing : bool = (not game_paused) and (Time.get_ticks_msec() / 1000.0 < absorb_until)

	if vaccum_particles != null:
		vaccum_particles.emitting = absorbing

	update_blood_tint(absorbing, delta)

func _physics_process(_delta: float) -> void:
	if game_paused:
		return
	var harvested: int = blood_impact_pool.harvest(car.global_position)
	if harvested > 0:
		fuel_up(harvested * fuel_per_splat)
		bloody_vaccum()

func _on_game_paused(game_on_pause :bool) -> void:
	game_paused = game_on_pause

func fuel_up(added_fuel : int) -> void :
	player.current_fuel += added_fuel
	if player.current_fuel > player.max_fuel.get_value() :
		player.current_fuel = int(player.max_fuel.get_value())
	fuel_bar.value = player.current_fuel

func bloody_vaccum() -> void :
	absorb_until = Time.get_ticks_msec() / 1000.0 + absorb_window


func update_blood_tint(absorbing : bool, delta : float) -> void:
	if car_sprite == null:
		return
	var mat : ShaderMaterial = car_sprite.material as ShaderMaterial
	if mat == null:
		return
	var target : float = 1.0 if absorbing else 0.0
	var raw : Variant = mat.get_shader_parameter("blood_amount")
	var current : float = raw if raw != null else 0.0
	mat.set_shader_parameter("blood_amount", lerp(current, target, tint_speed * delta))

func _on_gas_tank_picked_up() -> void :
	fuel_up(int(player.max_fuel.get_value() - player.current_fuel))

func fuel_consumption(fuel_q : int) -> void :
	player.current_fuel -= fuel_q
	if player.current_fuel <= 0:
		player.current_fuel = 0
	fuel_bar.value = player.current_fuel


func _on_fuel_timer_timeout() -> void:
	if game_paused :
		return
	fuel_consumption(player.regular_fuel_leak)

func _on_dash_started() -> void :
	fuel_consumption(player.dash_fuel_down)
