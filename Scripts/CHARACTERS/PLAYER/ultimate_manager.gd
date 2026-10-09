extends Node
class_name UltimateManager
## Car ultimate: charged over time (faster with the combo), triggered by closing a loop.
## The attack itself is the car's ultimate_scene, acting inside the loop drawn on the ground

@export var base_recharge_time: float = 20.0    # seconds to recharge at combo x1
@export var combo_recharge_share: float = 1.0   # share of the combo multiplier applied to the recharge speed
@export var combo_damage_share: float = 0.25    # share of the combo multiplier applied to the damage
@export var start_charged: bool = true          # generous: every raid starts with the ultimate ready

@onready var car: CharacterBody2D = $".."
@onready var maneuver_manager: ManeuverManager = $"../ManeuverManager"

var charge: float = 0.0  # 0..1, ready at 1
var combo_multiplier: float = 1.0
var game_paused: bool = false
var gauge: ProgressBar = null


func _ready() -> void:
	gauge = get_node_or_null("../../CanvasLayer/HUD/Combos/UltimateGauge") as ProgressBar
	if gauge != null:
		gauge.min_value = 0.0
		gauge.max_value = 1.0
		gauge.step = 0.0
		gauge.show_percentage = false
	charge = 1.0 if start_charged else 0.0
	SignalManager.maneuver_performed.connect(_on_maneuver_performed)
	SignalManager.combo_changed.connect(_on_combo_changed)
	SignalManager.game_paused.connect(_on_game_paused)
	_update_gauge()


func _physics_process(delta: float) -> void:
	if game_paused or charge >= 1.0:
		return
	# The combo speeds up the recharge
	var recharge_speed: float = 1.0 + (combo_multiplier - 1.0) * combo_recharge_share
	charge = minf(charge + delta * recharge_speed / base_recharge_time, 1.0)
	_update_gauge()


func _on_maneuver_performed(maneuver_type: ManeuverManager.Type, _intensity: float, _drift_level: int, _is_amplified: bool, _attack_angle: float) -> void:
	if maneuver_type != ManeuverManager.Type.LOOP or charge < 1.0:
		return
	var car_data: CarData = car.player
	if car_data == null or car_data.ultimate_scene == null:
		return
	var ultimate: Node2D = car_data.ultimate_scene.instantiate()
	var parent: Node = get_node_or_null("/root/World/VFX")
	if parent == null:
		parent = get_tree().current_scene
	parent.add_child(ultimate)
	# The loop polygon is in world space: the ultimate sits at the world origin
	ultimate.global_position = Vector2.ZERO
	ultimate.trigger(maneuver_manager.loop_polygon, 1.0 + (combo_multiplier - 1.0) * combo_damage_share)
	charge = 0.0
	_update_gauge()
	SignalManager.screen_shake_requested.emit(10.0, 0.5)


func _on_combo_changed(multiplier: float, _combo_count: int) -> void:
	combo_multiplier = multiplier


func _on_game_paused(game_on_pause: bool) -> void:
	game_paused = game_on_pause


func _update_gauge() -> void:
	if gauge != null:
		gauge.value = charge
