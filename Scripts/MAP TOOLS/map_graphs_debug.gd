extends Node2D
## Debug viewer for MapGenerator / MapData.
## Attach to a Node2D in an empty test scene and press T to generate a new map.
## Draws the rasterized cell grid (the same data gameplay will use), the road
## graph overlay and the extracted blocks. Wheel = zoom, drag = pan.

# ---------------- GENERATION PARAMETERS (mirrored into MapGenerator) ----------------
@export var map_seed : int = 0                          # 0 = new random seed each generation (logged in console)
@export var map_size_cells : Vector2i = Vector2i(96, 80)
@export var cell_size : int = 32
@export var lane_width_px : int = 96
@export var street_lanes : int = 2
@export var artery_lanes : int = 4
@export var border_margin_cells : int = 6
@export var block_interior_min : int = 4
@export var block_interior_max : int = 12
@export_range(0.0, 0.8) var removal_ratio : float = 0.1
@export var artery_count_h : int = 1
@export var artery_count_v : int = 1
@export var sidewalk_cells : int = 2
@export var zone_size_cells : Vector2i = Vector2i(2, 4) # entry / extraction openings (display only for now)

# ---------------- DEBUG DRAW ----------------
@export var show_cell_grid : bool = true
@export var show_graph : bool = true                    # edges + nodes overlay
@export var show_blocks : bool = true                   # per-block tint + bounding rects
@export var show_raster : bool = true                   # colored cell fill (turn off when a renderer is plugged)
@export var show_background : bool = true               # dark fill over the map area (turn off to see your own background)

# ---------------- RENDER PASSES ----------------
# MapRoadPaths node, rebuilt on each generation. Leave empty: it is looked up
# automatically anywhere in the scene (place it AFTER this node in the tree
# so its content draws above the debug background).
@export var road_paths : Node2D = null

# ---------------- DEBUG DRIVE ----------------
# Drop the RigidCar scene (debug_drive_mode ON) anywhere in the test scene:
# it is teleported to the entry zone on each generation, the camera follows it
# (F to toggle follow, dragging the view also releases it), and an invisible
# failsafe border (group "walls") closes the map.
@export var follow_car : bool = true

# ---------------- DEBUG CAMERA ----------------
@export var zoom_min : float = 0.1
@export var zoom_max : float = 3.0
@export var zoom_step : float = 1.1                     # multiplier per wheel notch
var camera : Camera2D = null
var dragging : bool = false

var generator : MapGenerator = MapGenerator.new()
var data : MapData = null
var walls_body : StaticBody2D = null
var car : Node2D = null
var car_camera : Camera2D = null

const COLOR_BG : Color = Color(0.09, 0.09, 0.11)
const COLOR_STREET : Color = Color(0.32, 0.33, 0.38)
const COLOR_SIDEWALK : Color = Color(0.19, 0.19, 0.22)
const COLOR_ARTERY : Color = Color(0.45, 0.42, 0.35)
const COLOR_GRAPH : Color = Color(0.9, 0.9, 0.95, 0.35)
const COLOR_NODE : Color = Color(0.9, 0.9, 0.95, 0.7)
const COLOR_ENTRY : Color = Color(0.25, 0.8, 0.35, 0.8)
const COLOR_EXIT : Color = Color(0.85, 0.25, 0.25, 0.8)
const COLOR_BORDER : Color = Color(0.8, 0.8, 0.85)

const BUILD_STEPS : int = 6

func _ready() -> void:
	add_to_group("map_generator")
	if GameMaster.is_debug():
		_setup_camera()
		generate.call_deferred()  # in game, World.build_level() drives it
	_build_failsafe_walls()


func _process(_delta : float) -> void:
	if not GameMaster.is_debug():
		return
	# Follow fallback, only used when the car has no Camera2D of its own
	if follow_car and car_camera == null and camera != null and is_instance_valid(car):
		camera.position = car.global_position


func _unhandled_input(event : InputEvent) -> void:
	if not GameMaster.is_debug():
		return
	var key : InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_T:
			generate()
		elif key.keycode == KEY_F:
			follow_car = not follow_car
			_update_view()
		return

	var mouse_button : InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null:
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			_zoom_at(mouse_button.position, zoom_step)
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			_zoom_at(mouse_button.position, 1.0 / zoom_step)
		elif mouse_button.button_index == MOUSE_BUTTON_LEFT or mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = mouse_button.pressed
			if dragging and follow_car:
				follow_car = false  # manual pan switches back to the free camera
				_update_view()
		return

	var mouse_motion : InputEventMouseMotion = event as InputEventMouseMotion
	if mouse_motion != null and dragging:
		camera.position -= mouse_motion.relative / camera.zoom.x


func generate() -> void:
	generate_async()


## Yields between passes so the loading overlay keeps drawing
func generate_async() -> void:
	_apply_params()
	LoadingScreen.set_step(0, BUILD_STEPS, "Drawing the district...")
	data = generator.generate(map_seed)
	await get_tree().process_frame

	LoadingScreen.set_step(1, BUILD_STEPS, "Adding buildings...")
	_build_buildings()
	await get_tree().process_frame

	LoadingScreen.set_step(2, BUILD_STEPS, "Adding sidewalks...")
	_build_sidewalks()
	await get_tree().process_frame

	LoadingScreen.set_step(3, BUILD_STEPS, "Adding cables, markings, trashes...")
	_build_cables()
	_build_road_lines()
	_build_road_marks()
	_build_debris()
	await get_tree().process_frame

	
	LoadingScreen.set_step(4, BUILD_STEPS, "Adding road wear and cracks...")
	_build_road_paths()
	_build_road_cracks()
	await get_tree().process_frame

	LoadingScreen.set_step(5, BUILD_STEPS, "Adding shadows...")
	_bake_shadows()
	await get_tree().process_frame

	LoadingScreen.set_step(6, BUILD_STEPS)
	queue_redraw()
	_place_car.call_deferred()
	SignalManager.map_generated.emit(data)


func _build_road_paths() -> void:
	# Auto-lookup so nothing depends on an inspector field being wired
	if road_paths == null or not is_instance_valid(road_paths):
		road_paths = _find_road_paths(get_tree().root)
	if road_paths == null:
		print("[MapGraph] no MapRoadPaths node found in the scene -> roads not drawn")
		return
	if not road_paths.has_method("build"):
		push_error("[MapGraph] node '%s' has no build() method: is map_road_paths.gd attached to it?" % road_paths.name)
		return
	print("[MapGraph] road paths node: ", road_paths.get_path())
	road_paths.call("build", data)


func _find_road_paths(node : Node) -> Node2D:
	# Type check, not file name: works whatever the script file is called
	if node is MapRoadPaths:
		return node as Node2D
	for child : Node in node.get_children():
		var found : Node2D = _find_road_paths(child)
		if found != null:
			return found
	return null


func _place_car() -> void:
	# Group lookup: works whether the car sits in World (game) or Lands (debug)
	car = get_tree().get_first_node_in_group("player") as Node2D
	if car == null:
		return
	# Entry mouth, on the main artery, facing right
	car.global_position = Vector2(float(border_margin_cells + 2), float(data.artery_y)) * float(cell_size)
	car.rotation = 0.0
	car.set("velocity", Vector2.ZERO)
	if not GameMaster.is_debug():
		return  # in game the car's own Camera2D is already current
	car_camera = car.get_node_or_null("Camera2D") as Camera2D
	_update_view()


func _update_view() -> void:
	if follow_car and car_camera != null:
		car_camera.make_current()
	elif camera != null:
		camera.make_current()


# ---------------- FAILSAFE WALLS ----------------
func _build_failsafe_walls() -> void:
	# Invisible closed border in the "walls" group (rigid_car reacts to it).
	# Fully closed for now: the buildings belt will later be the visual wall,
	# and openings will come with the entry/extraction gameplay pass.
	walls_body = StaticBody2D.new()
	walls_body.add_to_group("walls")
	# Debug walls live on ALL collision layers so they match the car's
	# collision_mask whatever the project's layer setup is
	walls_body.collision_layer = 0xFFFFFFFF if GameMaster.is_debug() else 4
	add_child(walls_body)
	var t : float = float(cell_size * 2)  # thickness
	var map_px : Vector2 = Vector2(map_size_cells) * float(cell_size)
	_add_wall(Rect2(-t, -t, map_px.x + 2.0 * t, t))        # top
	_add_wall(Rect2(-t, map_px.y, map_px.x + 2.0 * t, t))  # bottom
	_add_wall(Rect2(-t, 0.0, t, map_px.y))                 # left
	_add_wall(Rect2(map_px.x, 0.0, t, map_px.y))           # right


func _add_wall(rect : Rect2) -> void:
	var shape : CollisionShape2D = CollisionShape2D.new()
	var rectangle : RectangleShape2D = RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.position = rect.get_center()
	walls_body.add_child(shape)


func _apply_params() -> void:
	generator.map_size_cells = map_size_cells
	generator.cell_size = cell_size
	generator.lane_width_px = lane_width_px
	generator.street_lanes = street_lanes
	generator.artery_lanes = artery_lanes
	generator.border_margin_cells = border_margin_cells
	generator.block_interior_min = block_interior_min
	generator.block_interior_max = block_interior_max
	generator.removal_ratio = removal_ratio
	generator.artery_count_h = artery_count_h
	generator.artery_count_v = artery_count_v
	generator.sidewalk_cells = sidewalk_cells


# ---------------- DEBUG CAMERA ----------------
func _setup_camera() -> void:
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	var map_px : Vector2 = Vector2(map_size_cells) * float(cell_size)
	camera.position = map_px * 0.5
	var viewport_size : Vector2 = get_viewport_rect().size
	var fit_zoom : float = minf(viewport_size.x / map_px.x, viewport_size.y / map_px.y) * 0.95
	camera.zoom = Vector2.ONE * clampf(fit_zoom, zoom_min, zoom_max)


func _zoom_at(screen_pos : Vector2, factor : float) -> void:
	# Car view: simple zoom on the car's camera (it is attached to the car)
	if follow_car and car_camera != null:
		var car_zoom : float = clampf(car_camera.zoom.x * factor, zoom_min, zoom_max)
		car_camera.zoom = Vector2.ONE * car_zoom
		return
	# Free view: zoom while keeping the world point under the cursor fixed on screen
	var new_zoom : float = clampf(camera.zoom.x * factor, zoom_min, zoom_max)
	if is_equal_approx(new_zoom, camera.zoom.x):
		return
	var offset : Vector2 = screen_pos - get_viewport_rect().size * 0.5
	var world_point : Vector2 = camera.position + offset / camera.zoom.x
	camera.zoom = Vector2.ONE * new_zoom
	camera.position = world_point - offset / new_zoom


# ---------------- DEBUG DRAW ----------------
func _draw() -> void:
	if not GameMaster.is_debug():
		return
	if data == null:
		return
	var px : float = float(data.cell_size)
	var w : int = data.map_size_cells.x
	var h : int = data.map_size_cells.y
	var map_px : Vector2 = Vector2(data.map_size_cells) * px
	if show_background:
		draw_rect(Rect2(Vector2.ZERO, map_px), COLOR_BG, true)

	# Cell grid raster, merged into horizontal runs of identical color
	if show_raster:
		for y : int in h:
			var run_start : int = 0
			var run_color : Color = _cell_color(0, y)
			for x : int in range(1, w + 1):
				var color : Color = _cell_color(x, y) if x < w else Color.TRANSPARENT
				if color == run_color:
					continue
				if run_color.a > 0.0:
					draw_rect(Rect2(float(run_start) * px, float(y) * px, float(x - run_start) * px, px), run_color, true)
				run_start = x
				run_color = color

	if show_cell_grid:
		var grid_color : Color = Color(1.0, 1.0, 1.0, 0.045)
		for x : int in range(0, w + 1, 4):
			draw_line(Vector2(float(x) * px, 0.0), Vector2(float(x) * px, map_px.y), grid_color)
		for y : int in range(0, h + 1, 4):
			draw_line(Vector2(0.0, float(y) * px), Vector2(map_px.x, float(y) * px), grid_color)

	if show_blocks:
		for i : int in data.block_rects.size():
			var r : Rect2i = data.block_rects[i]
			var rect_px : Rect2 = Rect2(Vector2(r.position) * px, Vector2(r.size) * px)
			draw_rect(rect_px, _block_color(i, 0.9), false, 2.0)

	if show_graph:
		for i : int in data.edges.size():
			draw_line(data.nodes[data.edges[i].x] * px, data.nodes[data.edges[i].y] * px, COLOR_GRAPH, 3.0)
		for i : int in data.nodes.size():
			draw_circle(data.nodes[i] * px, 6.0, COLOR_NODE)

	# Entry / extraction zones, centered on the artery
	var zone_px : Vector2 = Vector2(zone_size_cells) * px
	var zone_top : float = float(data.artery_y) * px - zone_px.y * 0.5
	draw_rect(Rect2(Vector2(0.0, zone_top), zone_px), COLOR_ENTRY, true)
	draw_rect(Rect2(Vector2(map_px.x - zone_px.x, zone_top), zone_px), COLOR_EXIT, true)

	# Closed borders
	draw_rect(Rect2(Vector2.ZERO, map_px), COLOR_BORDER, false, 4.0)


func _cell_color(x : int, y : int) -> Color:
	match data.cell_type(x, y):
		MapData.CellType.STREET:
			return COLOR_STREET
		MapData.CellType.ARTERY:
			return COLOR_ARTERY
		MapData.CellType.SIDEWALK:
			return COLOR_SIDEWALK
		_:
			if show_blocks:
				return _block_color(data.cell_block_id[data.cell_index(x, y)], 0.16)
			return Color.TRANSPARENT


func _block_color(block_id : int, alpha : float) -> Color:
	# Golden-ratio hue walk: neighbouring ids get clearly distinct colors
	var color : Color = Color.from_hsv(fmod(float(block_id) * 0.618034, 1.0), 0.55, 0.85)
	color.a = alpha
	return color

func _build_buildings() -> void:
	var placer : MapBuildingsPlacer = _find_placer(get_tree().root)
	if placer == null:
		print("[MapGraph] no MapBuildingsPlacer node found in the scene -> buildings skipped")
		return
	placer.build(data)


func _find_placer(node : Node) -> MapBuildingsPlacer:
	if node is MapBuildingsPlacer:
		return node as MapBuildingsPlacer
	for child : Node in node.get_children():
		var found : MapBuildingsPlacer = _find_placer(child)
		if found != null:
			return found
	return null

func _build_sidewalks() -> void:
	var sidewalks : MapSidewalks = _find_sidewalks(get_tree().root)
	if sidewalks == null:
		print("[MapGraph] no MapSidewalks node found in the scene -> sidewalks skipped")
		return
	sidewalks.build(data)


func _find_sidewalks(node : Node) -> MapSidewalks:
	if node is MapSidewalks:
		return node as MapSidewalks
	for child : Node in node.get_children():
		var found : MapSidewalks = _find_sidewalks(child)
		if found != null:
			return found
	return null


func _bake_shadows() -> void:
	var shadows : MapShadowsGround = _find_shadows_ground(get_tree().root)
	if shadows == null:
		print("[MapGraph] no MapShadowsGround node found in the scene -> shadows not baked")
		return
	shadows.bake(Vector2i(data.map_size_cells) * data.cell_size)


func _find_shadows_ground(node : Node) -> MapShadowsGround:
	if node is MapShadowsGround:
		return node as MapShadowsGround
	for child : Node in node.get_children():
		var found : MapShadowsGround = _find_shadows_ground(child)
		if found != null:
			return found
	return null


func _build_cables() -> void:
	var cables : MapCables = _find_cables(get_tree().root)
	if cables == null:
		print("[MapGraph] no MapCables node found in the scene -> cables skipped")
		return
	var placer : MapBuildingsPlacer = _find_placer(get_tree().root)
	if placer == null:
		print("[MapGraph] no MapBuildingsPlacer found -> cables skipped")
		return
	cables.build(data, placer.building_rects)


func _find_cables(node : Node) -> MapCables:
	if node is MapCables:
		return node as MapCables
	for child : Node in node.get_children():
		var found : MapCables = _find_cables(child)
		if found != null:
			return found
	return null


func _build_road_cracks() -> void:
	var cracks : MapRoadCracks = _find_road_cracks(get_tree().root)
	if cracks == null:
		print("[MapGraph] no MapRoadCracks node found in the scene -> cracks skipped")
		return
	cracks.build(data)

func _find_road_cracks(node : Node) -> MapRoadCracks:
	if node is MapRoadCracks:
		return node as MapRoadCracks
	for child : Node in node.get_children():
		var found : MapRoadCracks = _find_road_cracks(child)
		if found != null:
			return found
	return null

func _build_road_marks() -> void:
	var marks : MapRoadMarks = _find_road_marks(get_tree().root)
	if marks == null:
		print("[MapGraph] no MapRoadMarks node found in the scene -> road marks skipped")
		return
	marks.build(data)


func _find_road_marks(node : Node) -> MapRoadMarks:
	if node is MapRoadMarks:
		return node as MapRoadMarks
	for child : Node in node.get_children():
		var found : MapRoadMarks = _find_road_marks(child)
		if found != null:
			return found
	return null


func _build_road_lines() -> void:
	var lines : MapRoadLines = _find_road_lines(get_tree().root)
	if lines == null:
		print("[MapGraph] no MapRoadLines node found in the scene -> road lines skipped")
		return
	lines.build(data)


func _find_road_lines(node : Node) -> MapRoadLines:
	if node is MapRoadLines:
		return node as MapRoadLines
	for child : Node in node.get_children():
		var found : MapRoadLines = _find_road_lines(child)
		if found != null:
			return found
	return null


func _build_debris() -> void:
	var debris : MapDebris = _find_debris(get_tree().root)
	if debris == null:
		print("[MapGraph] no MapDebris node found in the scene -> debris skipped")
		return
	debris.build(data)


func _find_debris(node : Node) -> MapDebris:
	if node is MapDebris:
		return node as MapDebris
	for child : Node in node.get_children():
		var found : MapDebris = _find_debris(child)
		if found != null:
			return found
	return null
