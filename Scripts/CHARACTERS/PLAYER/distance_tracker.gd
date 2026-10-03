class_name DistanceTracker
extends Node
# Child of the car: measures the distance driven and broadcasts it in whole meters

# Scale of the world: set it so a car length gives about 4 meters
@export var pixels_per_meter: float = 16.0
# Emit only every N meters, not every physics frame
@export var emit_step_meters: float = 10.0
# Larger jumps in one frame are teleports (respawn, reset), not driving
@export var max_step_pixels: float = 200.0

@onready var car: Node2D = get_parent() as Node2D

var last_position: Vector2 = Vector2.ZERO
# Fraction of meters not emitted yet, carried over to the next emit
var pending_meters: float = 0.0
var game_paused: bool = false


func _ready() -> void:
	last_position = car.global_position
	SignalManager.game_paused.connect(_on_game_paused)

func _physics_process(_delta: float) -> void:
	var current_position: Vector2 = car.global_position
	var step_pixels: float = current_position.distance_to(last_position)
	# Always updated, so resuming after a pause or a teleport adds no jump
	last_position = current_position
	if game_paused or step_pixels > max_step_pixels:
		return
	pending_meters += step_pixels / pixels_per_meter
	if pending_meters < emit_step_meters:
		return
	var whole_meters: int = int(pending_meters)
	pending_meters -= whole_meters
	SignalManager.distance_traveled.emit(whole_meters)

func _on_game_paused(game_on_pause: bool) -> void:
	game_paused = game_on_pause
