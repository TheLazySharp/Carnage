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

@export_group("Pit lane")
## Margin beyond the pit lane width before the car counts as out of it, in px
@export var pit_tolerance_px : float = 32.0

var pit_curve : Curve2D = null
var pit_zone : Rect2 = Rect2()        # coarse box around the whole lane, px
var pit_half_width : float = 0.0
var pit_entry_offset : float = 0.0    # start of the pit straight: crossed forward = entered
var pit_exit_offset : float = 0.0     # end of the pit straight: crossed forward = exited
var in_pit : bool = false
var last_pit_offset : float = -1.0    # -1 = car not on the pit lane last frame
var pit_lap : int = -1                # laps_completed when the pit was last used, -1 = never
var pit_stops : int = 0
var pit_stop_done : bool = false      # stand used (shop opened) during the current visit

func _ready() -> void:
	SignalManager.map_generated.connect(_on_map_generated)
	SignalManager.game_paused.connect(_on_game_paused)
	SignalManager.game_is_over.connect(_on_game_over)
	SignalManager.pit_stop_used.connect(_on_pit_stop_used)
	set_physics_process(false)


func _on_map_generated(map_data : MapData) -> void:
	if map_data.track_curve == null:
		set_physics_process(false)  # city map: nothing to count
		return
	data = map_data
	lap_px = 4.0 * data.track_half_straight_px + TAU * data.track_radius_px
	target = get_tree().get_first_node_in_group("player") as Node2D
	_setup_pit(map_data)
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
		if in_pit:
			_leave_pit(false)  # regenerated while in the pit: close it cleanly
		last_pit_offset = -1.0
		pit_lap = -1
		return

	# Before the teleport guard below: a rejected frame must not skip the pit
	_update_pit(pos)

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

func _setup_pit(map_data : MapData) -> void:
	pit_curve = map_data.pit_curve
	in_pit = false
	if pit_curve == null or pit_curve.get_point_count() < 4:
		pit_curve = null
		return
	pit_half_width = float(map_data.pit_width_px) * 0.5 + pit_tolerance_px
	# The pit straight runs between curve points 1 and 2 (see TrackGenerator):
	# its two ends are the entry and exit lines
	pit_entry_offset = pit_curve.get_closest_offset(pit_curve.get_point_position(1))
	pit_exit_offset = pit_curve.get_closest_offset(pit_curve.get_point_position(2))
	# Coarse box around the whole lane: the curve query only runs near the pit
	var baked : PackedVector2Array = pit_curve.get_baked_points()
	pit_zone = Rect2(baked[0], Vector2.ZERO)
	for point : Vector2 in baked:
		pit_zone = pit_zone.expand(point)
	pit_zone = pit_zone.grow(pit_half_width)


func _update_pit(pos : Vector2) -> void:
	if pit_curve == null:
		return
	var on_lane : bool = false
	var pit_offset : float = -1.0
	if pit_zone.has_point(pos):
		pit_offset = pit_curve.get_closest_offset(pos)
		on_lane = pos.distance_to(pit_curve.sample_baked(pit_offset)) <= pit_half_width
	if not on_lane:
		# Left the lane sideways (cut across the grass), or never was on it
		if in_pit:
			_leave_pit(false)
		last_pit_offset = -1.0
		return
	# The first frame on the lane only records the offset: jumping onto the
	# lane mid-way can never count as an entry
	if last_pit_offset >= 0.0:
		var crossed_entry : bool = last_pit_offset < pit_entry_offset and pit_offset >= pit_entry_offset
		if not in_pit and crossed_entry:
			if pit_lap == laps_completed or pit_stops == DeadLapsManager.max_pit_stops:
				if pit_lap == laps_completed :
					print("[LapCounter] pit refused: already used this lap")
				if pit_stops == DeadLapsManager.max_pit_stops :
					print("[LapCounter] pit refused: max pit stops reached")
			else:
				# Entry line crossed forward. Coming from the exit side never
				# lands here: the reverse path triggers nothing at all
				in_pit = true
				pit_lap = laps_completed
				pit_stop_done = false
				print("[LapCounter] pit entered")
				SignalManager.emit_signal("pit_entered")
		elif in_pit and last_pit_offset < pit_exit_offset and pit_offset >= pit_exit_offset and pit_stops < DeadLapsManager.max_pit_stops:
			_leave_pit(true)
		elif in_pit and last_pit_offset >= pit_entry_offset and pit_offset < pit_entry_offset or pit_stops >= DeadLapsManager.max_pit_stops:
			_leave_pit(false)  # turned back and drove out through the entry
	last_pit_offset = pit_offset


func _leave_pit(via_exit_line : bool) -> void:
	in_pit = false
	# The stop counts once it has been used (shop opened), whatever the way
	# out: exit line, reversing through the entry, or across the grass
	print("[LapCounter] pit exited (via exit line: ", via_exit_line, ", stop done: ", pit_stop_done, ")")
	SignalManager.pit_exited.emit(pit_stop_done)

## Share of the current lap legitimately driven, 0..1, for the HUD
func get_lap_ratio() -> float:
	if lap_px <= 0.0:
		return 0.0
	return clampf(lap_distance / lap_px, 0.0, 1.0)


func _on_line_crossed() -> void:
	if not started:
		started = true
		lap_distance = 0.0
		print("[LapCounter] race started")
		SignalManager.emit_signal("race_started")
		return
	if lap_distance >= lap_px * min_valid_lap_ratio:
		laps_completed += 1
		print("[LapCounter] lap ", laps_completed)
		SignalManager.emit_signal("lap_completed",laps_completed)
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

func _on_pit_stop_used() -> void:
	if in_pit:
		pit_stop_done = true
