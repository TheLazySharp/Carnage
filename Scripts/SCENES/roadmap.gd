extends Node2D
class_name  RoadMap

const SCROLL_SPEED : int = 15
const MAP_LINE = preload("uid://c1x3sw3es8h4c")
const DISTRICT = preload("uid://dy7ucna56qsok") #map_district scene
@onready var available_seats: Label = $MapBackground/AvailableSeats



@onready var camera_2d: Camera2D = $Camera2D
@onready var visuals: Node2D = $MapBackground/ControlMap/Visuals
@onready var lines: Node2D = %Lines
@onready var districts: Node2D = %Districts
#@onready var map_generator: PathGenerator = $MapGenerator

var map_data : Array[Array]

var last_district : DistrictsData
var visual_edge_x : float
var button_index : int = 0


func _ready() -> void:
	SignalManager.selected_district.connect(_on_map_district_selected)
	visual_edge_x = RoadMapManager.Y_DIST * (RoadMapManager.STEPS -1)
	available_seats.text = "Available seats : " + str(CarManager.selected_car.seats - SurvivorsManager.on_board_survivors.size()) + " / " + str(CarManager.selected_car.seats)
	if RoadMapManager.last_district:
		last_district = RoadMapManager.last_district
	else :
		last_district = null
	generate_new_map()
	unlock_step(RoadMapManager.steps_reached)
	#print("selected map districts : ",RoadMapManager.selected_districts.size())
	


func generate_new_map() -> void : 
	if RoadMapManager.current_map_data.is_empty():
		RoadMapManager.steps_reached = 0
		map_data = RoadMapManager.generate_map()
	else :
		map_data = RoadMapManager.current_map_data
	create_map()

func unlock_step(step : int = RoadMapManager.steps_reached) -> void : 
	if step == 0 :
		for map_district : MapDistrict in districts.get_children():
			if map_district.district.row == 0 and step == 0:
				map_district.available = true
	
	else : 
		for map_district : MapDistrict in districts.get_children():
			if last_district.next_districts.has(map_district.district):
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
	
	var middle: int = floori(RoadMapManager.GRID_WIDTH * 0.5)
	spawn_district(map_data[RoadMapManager.STEPS-1][middle])
	
	var map_height_pixels : int = RoadMapManager.Y_DIST * (RoadMapManager.GRID_WIDTH - 1)
	visuals.position.y = (get_viewport_rect().size.y + map_height_pixels) * 0.5
	visuals.position.x = 100

func spawn_district(district : DistrictsData) -> void : 
	var new_map_district := DISTRICT.instantiate() as MapDistrict
	districts.add_child(new_map_district)
	new_map_district.district = district
	#new_map_district.selected.connect(_on_map_district_selected)
	connect_lines(district)
	
	if district.selected and district.row < RoadMapManager.steps_reached:
		new_map_district.show_selected()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("scroll_up"):
		visuals.position.x -= SCROLL_SPEED
	elif event.is_action_pressed("scroll_down"):
		visuals.position.x += SCROLL_SPEED
	
	visuals.position.x = clamp(visuals.position.x, - RoadMapManager.X_DIST * 3, max(visual_edge_x * 1.5,get_viewport_rect().size.x - 100))

	if event.is_action_pressed("ui_back"):
		if SceneManager.previous_scene == SceneManager.SCENES.CAR_SELECTION:
			SceneManager.load_level(SceneManager.SCENES.CAR_SELECTION)
		else :
			SceneManager.load_level(SceneManager.SCENES.HOME)
			

func _on_map_district_selected(district : DistrictsData)-> void : 
	for map_district : MapDistrict in districts.get_children():
		if map_district.district.row == district.row : 
			map_district.available = false
	
	RoadMapManager.last_district = district
	RoadMapManager.selected_districts.append(district)
	#RoadMapManager.steps_reached += 1
	print(district.type)

func connect_lines(district : DistrictsData) -> void : 
	if district.next_districts.is_empty():
		return
	
	for next : DistrictsData in district.next_districts:
		var new_map_line := MAP_LINE.instantiate() as Line2D
		new_map_line.add_point(district.position)
		new_map_line.add_point(next.position)
		lines.add_child(new_map_line)
