class_name LapCounter
extends Node
## Lap counting on oval districts, by distance actually driven along the lap
## (MapData.track_progress_at), never by trigger areas: crossing the line back
## and forth, cutting through the infield or teleporting counts for nothing.
## A lap is validated on a FORWARD crossing of the start line, if enough
## distance was driven ON the racing surface since the previous crossing.

## Share of the lap that must be driven on the track for it to count. The
## slack absorbs the pit detour and short excursions off the asphalt.
@export_range(0.5, 1.0, 0.01) var min_valid_lap_ratio : float = 0.92
## Top speed of the car, in px/s. A frame moving farther than this (x1.5)
## along the lap is a teleport or a projection jump: ignored.
@export var max_speed_px_s : float = 1500.0
## Wheels may leave the asphalt by this much and still count as on track, in px
@export var off_track_tolerance_px : float = 32.0
## Time spent driving backward along the lap before "wrong way" is raised, in s
@export var wrong_way_delay_s : float = 0.6

var data : MapData = null
var target : Node2D = null
var lap_px : float = 0.0
var laps_completed : int = 0
var lap_distance : float = 0.0      # legit distance driven since the last crossing
var last_offset : float = 0.0
var started : bool = false          # first forward crossing = race start, not a lap
var wrong_way : bool = false
var wrong_way_time : float = 0.0
var needs_init : bool = false
var game_paused : bool = false
var game_over : bool = false


func _ready() -> void:
	SignalManager.map_generated.connect(_on_map_generated)
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.game_is_over.connect(_on_game_over)
	set_physics_process(false)


func _on_map_generated(map_data : MapData) -> void:
	if map_data.track_curve == null:
		set_physics_process(false)  # city map: nothing to count
		return
	data = map_data
	lap_px = 4.0 * data.track_half_straight_px + TAU * data.track_radius_px
	target = get_tree().get_first_node_in_group("player") as Node2D
	# The car is put on the grid by a DEFERRED call: sample its position on
	# the next physics frame, not now
	needs_init = true
	set_physics_process(target != null)


func _physics_process(delta : float) -> void:
	if game_paused or game_over or not is_instance_valid(target):
		return
	var pos : Vector2 = target.global_position
	var offset : float = data.track_progress_at(pos)
	if needs_init:
		needs_init = false
		last_offset = offset
		lap_distance = 0.0
		laps_completed = 0
		started = false
		_set_wrong_way(false)
		return

	# Signed move along the lap, corrected where the offset wraps (the line)
	var step : float = offset - last_offset
	var crossed_forward : bool = false
	if step < -lap_px * 0.5:
		step += lap_px
		crossed_forward = true
	elif step > lap_px * 0.5:
		step -= lap_px
	last_offset = offset

	# Teleport, respawn or projection jump across the infield: ignore the frame
	if absf(step) > max_speed_px_s * 1.5 * delta:
		return

	if _is_on_track(pos):
		lap_distance += step
	_update_wrong_way(step, delta)
	if crossed_forward:
		_on_line_crossed()


## Share of the current lap legitimately driven, 0..1, for the HUD
func get_lap_ratio() -> float:
	if lap_px <= 0.0:
		return 0.0
	return clampf(lap_distance / lap_px, 0.0, 1.0)


func _on_line_crossed() -> void:
	if not started:
		# Leaving the grid: the race starts, nothing to bank yet
		started = true
		lap_distance = 0.0
		print("[LapCounter] race started")
		SignalManager.race_started.emit()
		return
	if lap_distance >= lap_px * min_valid_lap_ratio:
		laps_completed += 1
		print("[LapCounter] lap ", laps_completed)
		SignalManager.lap_completed.emit(laps_completed)
	elif lap_distance > lap_px * 0.25:
		# A real attempt, but cut: report it. A jiggle on the line stays silent.
		print("[LapCounter] lap rejected (", int(lap_distance / lap_px * 100.0), "% driven on track)")
		SignalManager.lap_rejected.emit()
	lap_distance = 0.0


func _is_on_track(pos : Vector2) -> bool:
	var half : float = float(data.track_width_px) * 0.5 + off_track_tolerance_px
	if absf(data.track_lateral_at(pos)) <= half:
		return true
	# The pit strip runs along the top straight: driving through it is legit
	var cell : Vector2i = data.world_to_cell(pos)
	if cell.x < 0 or cell.y < 0 or cell.x >= data.map_size_cells.x or cell.y >= data.map_size_cells.y:
		return false
	return data.cell_type(cell.x, cell.y) == MapData.CellType.PIT


func _update_wrong_way(step : float, delta : float) -> void:
	# Driving backward along the lap for a while, not a spin or a bump
	if step < -0.5:
		wrong_way_time += delta
	elif step > 0.5:
		wrong_way_time = 0.0
	_set_wrong_way(wrong_way_time >= wrong_way_delay_s)


func _set_wrong_way(value : bool) -> void:
	if value == wrong_way:
		return
	wrong_way = value
	print("[LapCounter] wrong way: ", wrong_way)
	SignalManager.wrong_way_changed.emit(wrong_way)


func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause


func _on_game_over(game_is_over : bool) -> void:
	game_over = game_is_over
