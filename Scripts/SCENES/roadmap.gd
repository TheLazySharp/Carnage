extends Node2D
class_name  RoadMap

const SCROLL_SPEED : int = 15
const MAP_LINE = preload("uid://c1x3sw3es8h4c")
const DISTRICT = preload("uid://dy7ucna56qsok") #map_district scene

@onready var camera_2d: Camera2D = $Camera2D
@onready var visuals: Node2D = $Visuals
@onready var lines: Node2D = %Lines
@onready var districts: Node2D = %Districts
@onready var map_generator: PathGenerator = $MapGenerator

var map_data : Array[Array]
var steps_reached : int
var last_district : DistrictsData
var camera_edge_y : float

func _ready() -> void:
	camera_edge_y = PathGenerator.Y_DIST * (PathGenerator.STEPS -1) * 2
	
	generate_new_map()
	unlock_step(0)

func generate_new_map() -> void : 
	steps_reached = 0
	map_data = map_generator.generate_map()
	create_map()

func unlock_step(step : int = steps_reached) -> void : 
	for map_district : MapDistrict in districts.get_children():
		if map_district.district.row == step:
			map_district.available = true

func unlock_next_rooms() -> void : 
	for map_district : MapDistrict in districts.get_children():
		if last_district.next_districts.has(map_district.district):
			map_district.available = true

func show_map() -> void : 
	show()
	camera_2d.enabled = true

func hide_map() -> void : 
	hide()
	camera_2d.enabled = false

func create_map() -> void : 
	for current_step: Array in map_data:
		for district : DistrictsData in current_step:
			if district.next_districts.size() > 0 : 
				spawn_district(district)
	
	var middle: int = floori(PathGenerator.GRID_WIDTH * 0.5)
	spawn_district(map_data[PathGenerator.STEPS-1][middle])
	
	var map_width_pixels : int = PathGenerator.X_DIST * (PathGenerator.GRID_WIDTH - 1)
	visuals.position.x = (get_viewport_rect().size.x - map_width_pixels) * 0.5
	visuals.position.y = get_viewport_rect().size.y * 0.5

func spawn_district(district : DistrictsData) -> void : 
	var new_map_district := DISTRICT.instantiate() as MapDistrict
	districts.add_child(new_map_district)
	new_map_district.district = district
	new_map_district.selected.connect(_on_map_district_selected)
	connect_lines(district)
	
	if district.selected and district.row < steps_reached:
		new_map_district.show_selected()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("scroll_up"):
		camera_2d.position.y -= SCROLL_SPEED
	elif event.is_action_pressed("scroll_down"):
		camera_2d.position.y += SCROLL_SPEED
	
	camera_2d.position.y = clamp(camera_2d.position.y, 0, camera_edge_y)

func _on_map_district_selected(district : DistrictsData)-> void : 
	for map_district : MapDistrict in districts.get_children():
		if map_district.district.row == district.row : 
			map_district.available = false
	
	last_district = district
	steps_reached += 1
	print("load ",district.type) 
	# -------------------- TO DO : LOAD THE DIFFERENT TYPE OF DISTRICTS -------------------------------------

func connect_lines(district : DistrictsData) -> void : 
	if district.next_districts.is_empty():
		return
	
	for next : DistrictsData in district.next_districts:
		var new_map_line := MAP_LINE.instantiate() as Line2D
		new_map_line.add_point(district.position)
		new_map_line.add_point(next.position)
		lines.add_child(new_map_line)
