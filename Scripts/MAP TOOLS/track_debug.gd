extends Node2D
## Debug viewer for TrackGenerator. Press T to regenerate, wheel to zoom,
## drag to pan. Draws the rasterized cells and the centreline.

# ---------------- GENERATION PARAMETERS ----------------
@export var map_seed : int = 0                        # 0 = new seed each time
@export var map_size_cells : Vector2i = Vector2i(96, 80)
@export var cell_size : int = 32
@export var lane_width_px : int = 96
@export var track_lanes : int = 4
@export var pit_size_cells : Vector2i = Vector2i(16, 6)
@export var pit_inset_cells : int = 3
@export var border_margin_h_cells : int = 2
@export var border_margin_v_cells : int = 8

@export_group("Passes")
@export var sidewalks : MapSidewalks = null
@export var road_paths : TrackRoadPaths = null
@export var road_lines : TrackRoadLines = null
## Start/finish Area2D: placed and sized on the generated line every build
@export var finish_line : Area2D = null
## Thickness along the travel direction, in px
@export var finish_line_thickness_px : float = 32.0


@export_group("Debug draw")
## Dark fill over the map area: turn off to see your own background
@export var show_background : bool = false
## Colored cell fill: turn off once the real renderers are plugged
@export var show_raster : bool = false
@export var show_cell_grid : bool = false
## Centreline, start line tick, direction arrow and pit outline
@export var show_curve : bool = true
@export var show_grid : bool = true

@export_group("Car")
## Distance between the start line and the car centre, in px (32 px = 2.25 m)
@export var car_grid_back_px : float = 96.0
## Lateral slot on the grid, in px (< 0 = infield side).
## -144 = inside lane: the pole position on a real oval
@export var car_grid_lateral_px : float = -144.0

# ---------------- DEBUG CAMERA ----------------
@export var zoom_min : float = 0.1
@export var zoom_max : float = 3.0
@export var zoom_step : float = 1.1


var generator : TrackGenerator = TrackGenerator.new()
var data : MapData = null
var camera : Camera2D = null
var dragging : bool = false

const COLOR_BG : Color = Color(0.09, 0.09, 0.11)
const COLOR_TRACK : Color = Color(0.32, 0.33, 0.38)
const COLOR_PIT : Color = Color(0.25, 0.45, 0.30)
const COLOR_FREE : Color = Color(0.17, 0.17, 0.20)
const COLOR_CURVE : Color = Color(0.95, 0.85, 0.30, 0.9)
const COLOR_START : Color = Color(0.95, 0.25, 0.25)
const TRACK_BUILD_STEPS : int = 4

func _ready() -> void:
	add_to_group("map_generator")
	if GameMaster.is_debug():
		_setup_camera()
		generate.call_deferred()  # in game, World.build_level() drives it


func generate() -> void:
	generate_async()


## Same contract as Lands: yields between passes so the loading overlay keeps
## drawing, then hands the map to the gameplay systems (spawners, flow field)
func generate_async() -> void:
	generator.map_size_cells = map_size_cells
	generator.cell_size = cell_size
	generator.lane_width_px = lane_width_px
	generator.track_lanes = track_lanes
	generator.border_margin_h_cells = border_margin_h_cells
	generator.border_margin_v_cells = border_margin_v_cells
	generator.pit_size_cells = pit_size_cells
	generator.pit_inset_cells = pit_inset_cells

	LoadingScreen.set_step(0, TRACK_BUILD_STEPS, "Drawing the track...")
	data = generator.generate(map_seed)
	await get_tree().process_frame

	LoadingScreen.set_step(1, TRACK_BUILD_STEPS, "Laying the infield...")
	if sidewalks != null:
		sidewalks.build(data)
	await get_tree().process_frame

	LoadingScreen.set_step(2, TRACK_BUILD_STEPS, "Laying the asphalt...")
	if road_paths != null:
		await road_paths.build(data)  # waits for the bake: no pop-in after the overlay

	LoadingScreen.set_step(3, TRACK_BUILD_STEPS, "Painting the markings...")
	if road_lines != null:
		await road_lines.build(data)  # waits for the bake: no pop-in after the overlay
	_place_finish_line()
	await get_tree().process_frame

	LoadingScreen.set_step(TRACK_BUILD_STEPS, TRACK_BUILD_STEPS)
	queue_redraw()
	# Deferred: on the very first generation the car may not have entered its
	# group yet
	_place_car_on_grid.call_deferred()
	SignalManager.map_generated.emit(data)
	SignalManager.emit_signal("beacon_start")


func _unhandled_input(event : InputEvent) -> void:
	if not GameMaster.is_debug():
		return
	var key : InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_T:
		generate()
		return

	var button : InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_zoom_at(button.position, zoom_step)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_zoom_at(button.position, 1.0 / zoom_step)
		elif button.button_index == MOUSE_BUTTON_LEFT or button.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = button.pressed
		return

	var motion : InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and dragging and camera != null:
		camera.position -= motion.relative / camera.zoom.x


# ---------------- CAMERA ----------------
func _setup_camera() -> void:
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	var map_px : Vector2 = Vector2(map_size_cells) * float(cell_size)
	camera.position = map_px * 0.5
	var view : Vector2 = get_viewport_rect().size
	var fit : float = minf(view.x / map_px.x, view.y / map_px.y) * 0.95
	camera.zoom = Vector2.ONE * clampf(fit, zoom_min, zoom_max)


func _zoom_at(screen_pos : Vector2, factor : float) -> void:
	var new_zoom : float = clampf(camera.zoom.x * factor, zoom_min, zoom_max)
	if is_equal_approx(new_zoom, camera.zoom.x):
		return
	var offset : Vector2 = screen_pos - get_viewport_rect().size * 0.5
	var world_point : Vector2 = camera.position + offset / camera.zoom.x
	camera.zoom = Vector2.ONE * new_zoom
	camera.position = world_point - offset / new_zoom


# ---------------- DEBUG DRAW ----------------
func _draw() -> void:
	if data == null or not GameMaster.is_debug():
		return
	var px : float = float(data.cell_size)
	var w : int = data.map_size_cells.x
	var h : int = data.map_size_cells.y
	var map_px : Vector2 = Vector2(data.map_size_cells) * px

	if show_background:
		draw_rect(Rect2(Vector2.ZERO, map_px), Color(0.09, 0.09, 0.11), true)

	# Cell raster merged into horizontal runs of the same type.
	# Indexed by MapData.CellType: FREE, STREET, ARTERY, SIDEWALK, BUILDING, PIT
	if show_raster:
		var palette : PackedColorArray = PackedColorArray([
			Color.TRANSPARENT,
			Color(0.32, 0.33, 0.38),
			Color(0.45, 0.42, 0.35),
			Color(0.19, 0.19, 0.22),
			Color(0.42, 0.30, 0.24),
			Color(0.25, 0.60, 0.35),
		])
		for y : int in h:
			var run_start : int = 0
			var run_type : int = data.cell_type(0, y)
			for x : int in range(1, w + 1):
				var t : int = data.cell_type(x, y) if x < w else -1
				if t == run_type:
					continue
				var color : Color = palette[run_type]
				if color.a > 0.0:
					draw_rect(Rect2(float(run_start) * px, float(y) * px,
							float(x - run_start) * px, px), color, true)
				run_start = x
				run_type = t

	if show_cell_grid:
		var grid_color : Color = Color(1.0, 1.0, 1.0, 0.045)
		for x : int in range(0, w + 1, 4):
			draw_line(Vector2(float(x) * px, 0.0), Vector2(float(x) * px, map_px.y), grid_color)
		for y : int in range(0, h + 1, 4):
			draw_line(Vector2(0.0, float(y) * px), Vector2(map_px.x, float(y) * px), grid_color)

	if show_curve and data.track_curve != null:
		draw_polyline(data.track_curve.get_baked_points(), Color(1.0, 1.0, 1.0, 0.5), 2.0)

		# Start line at offset 0 + direction arrow
		var red : Color = Color(1.0, 0.2, 0.2)
		var start : Vector2 = data.track_curve.sample_baked(0.0)
		var dir : Vector2 = (data.track_curve.sample_baked(64.0) - start).normalized()
		var normal : Vector2 = Vector2(-dir.y, dir.x)
		var half : float = float(data.track_width_px) * 0.5
		draw_line(start - normal * half, start + normal * half, red, 4.0)
		var tip : Vector2 = start + dir * 128.0
		draw_line(start, tip, red, 3.0)
		draw_line(tip, tip - dir * 32.0 + normal * 20.0, red, 3.0)
		draw_line(tip, tip - dir * 32.0 - normal * 20.0, red, 3.0)

		# Pit outline
		if data.pit_rect.size != Vector2i.ZERO:
			draw_rect(Rect2(Vector2(data.pit_rect.position) * px, Vector2(data.pit_rect.size) * px),
					Color(0.3, 0.9, 0.4), false, 2.0)

	# Map border
	draw_rect(Rect2(Vector2.ZERO, map_px), Color(0.8, 0.8, 0.85), false, 4.0)


func _cell_color(x : int, y : int) -> Color:
	match data.cell_type(x, y):
		MapData.CellType.ARTERY:
			return COLOR_TRACK
		MapData.CellType.PIT:
			return COLOR_PIT
		MapData.CellType.FREE:
			return COLOR_FREE
		_:
			return Color.TRANSPARENT

func _place_car_on_grid() -> void:
	var player_car : Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player_car == null or data == null or data.track_curve == null:
		return
	# Offset 0 of the track curve IS the start line: step back against the
	# travel direction, then sideways into the grid slot
	var start : Vector2 = data.track_curve.sample_baked(0.0)
	var dir : Vector2 = (data.track_curve.sample_baked(32.0) - start).normalized()
	var normal : Vector2 = Vector2(-dir.y, dir.x)  # points toward the wall
	var pos : Vector2 = start - dir * car_grid_back_px + normal * car_grid_lateral_px
	# Rotation 0 faces +X, as in Lands: dir.angle() faces the travel direction
	var xform : Transform2D = Transform2D(dir.angle(), pos)
	player_car.global_transform = xform

	var body : RigidBody2D = player_car as RigidBody2D
	if body != null:
		# A rigid body rewrites its transform on the next physics step:
		# teleport it on the physics server too, and kill its momentum
		PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, xform)
		body.linear_velocity = Vector2.ZERO
		body.angular_velocity = 0.0
	else:
		player_car.set("velocity", Vector2.ZERO)
	print("[TrackDebug] car on the grid at ", pos)


func _place_finish_line() -> void:
	if finish_line == null or data == null or data.track_curve == null:
		return
	# Offset 0 of the track curve IS the start/finish line
	var start : Vector2 = data.track_curve.sample_baked(0.0)
	var dir : Vector2 = (data.track_curve.sample_baked(32.0) - start).normalized()
	finish_line.global_position = start
	finish_line.rotation = dir.angle()
	var shape : CollisionShape2D = finish_line.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null or not (shape.shape is RectangleShape2D):
		push_warning("[TrackDebug] finish_line needs a CollisionShape2D child with a RectangleShape2D")
		return
	# Thin along the travel direction, spans the whole track across it
	(shape.shape as RectangleShape2D).size = Vector2(finish_line_thickness_px, float(data.track_width_px))
