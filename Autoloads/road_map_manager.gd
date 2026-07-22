extends Node

const X_DIST : int = 88
const Y_DIST : int = 104
const DIST_RANDOMNESS : int = 24
const STEPS : int = 12
const GRID_WIDTH : int = 5
const PATHS : int = 5


const DISTRICT_WEIGHTS_BY_BIOME : Dictionary = {
	GameMaster.BIOMES.CITY : {
		DistrictsData.types.ARENA : 3,
		DistrictsData.types.HIGHWAY : 1,
		DistrictsData.types.SURVIVOR : 2,
		DistrictsData.types.EVENT : 1,
		DistrictsData.types.BANK : 3,
		DistrictsData.types.GUNSHOP : 3,
		DistrictsData.types.CARDEALER : 1,
		DistrictsData.types.SHOP : 2,
		DistrictsData.types.GARAGE : 2,
	},
	GameMaster.BIOMES.COUNTRYSIDE : {
		DistrictsData.types.ARENA : 2,
		DistrictsData.types.HIGHWAY : 4,
		DistrictsData.types.SURVIVOR : 2,
		DistrictsData.types.EVENT : 2,
		DistrictsData.types.BANK : 1,
		DistrictsData.types.GUNSHOP : 2,
		DistrictsData.types.CARDEALER : 2,
		DistrictsData.types.SHOP : 1,
		DistrictsData.types.GARAGE : 2,
	},
	GameMaster.BIOMES.DESERT : {
		DistrictsData.types.ARENA : 1,
		DistrictsData.types.HIGHWAY : 2,
		DistrictsData.types.SURVIVOR : 2,
		DistrictsData.types.EVENT : 4,
		DistrictsData.types.BANK : 1,
		DistrictsData.types.GUNSHOP : 1,
		DistrictsData.types.CARDEALER : 2,
		DistrictsData.types.SHOP : 3,
		DistrictsData.types.GARAGE : 2,
	},
	GameMaster.BIOMES.HARBOR : {
		DistrictsData.types.ARENA : 2,
		DistrictsData.types.HIGHWAY : 1,
		DistrictsData.types.SURVIVOR : 2,
		DistrictsData.types.EVENT : 1,
		DistrictsData.types.BANK : 3,
		DistrictsData.types.GUNSHOP : 2,
		DistrictsData.types.CARDEALER : 3,
		DistrictsData.types.SHOP : 2,
		DistrictsData.types.GARAGE : 2,
	},
}

var random_districts_weights : Dictionary = {}
var random_districts_total_weights : int = 0


const SHOP_DISTRICTS_WEIGHT : float = 4.0
const GARAGE_DISTRICTS_WEIGHT : float = 6.0
const ARENA_DISTRICTS_WEIGHT : float = 15.0
const SURVIVOR_DISTRICTS_WEIGHT : float = 8.0
const HIGHWAY_DISTRICTS_WEIGHT : float = 4.0
const GUNSHOP_DISTRICTS_WEIGHT : float = 2.0
const CARDEALER_DISTRICTS_WEIGHT : float = 2.0
const BANK_DISTRICTS_WEIGHT : float = 2.0
const EVENT_DISTRICTS_WEIGHT : float = 3.0

var steps_reached : int = 0
var current_map_data : Array[Array]
var last_district : DistrictsData

#var random_districts_weights : Dictionary = {
	#DistrictsData.types.GARAGE : 0.0,
	#DistrictsData.types.ARENA : 0.0,
	#DistrictsData.types.SURVIVOR : 0.0,
	#DistrictsData.types.SHOP : 0.0,
	#DistrictsData.types.HIGHWAY : 0.0,
	#DistrictsData.types.EVENT : 0.0,
	#DistrictsData.types.BANK : 0.0,
	#DistrictsData.types.CARDEALER : 0.0,
	#DistrictsData.types.GUNSHOP : 0.0,
	#DistrictsData.types.FINAL : 0.0
#}

signal new_step_reached(new_step : int)
var map_data : Array[Array] #Grid is an array of floors which are array of districts
var selected_districts : Array[DistrictsData]

func _ready() -> void:
	SignalManager.next_day.connect(_on_next_day)

func generate_map(_biome : GameMaster.BIOMES = GameMaster.current_biome) -> Array[Array] :
	
	map_data = generate_initial_grid()
	var starting_points : Array[int] = get_random_starting_points()
	
	for j in starting_points:
		var current_j : int = j
		for i in STEPS - 1:
			current_j = setup_connection(i, current_j)

	setup_final_district()
	setup_random_district_weights()
	setup_district_types()

	
	current_map_data = map_data
	return map_data

func generate_initial_grid() -> Array[Array] : 
	var result : Array[Array] = []
	
	for i in STEPS:
		var adjacent_districts : Array[DistrictsData] = []
		
		for j in GRID_WIDTH:
			var current_district : DistrictsData = DistrictsData.new()
			var offset : Vector2 = Vector2(randf(),randf()) * DIST_RANDOMNESS
			current_district.position = Vector2(i * X_DIST, j * - Y_DIST) + offset
			current_district.row = i
			current_district.column = j
			current_district.next_districts = []
			
			#final district bigger distance
			if i == STEPS -1 : 
				current_district.position.x = (i + 1) * X_DIST
			
			adjacent_districts.append(current_district)

		result.append(adjacent_districts)
	
	return result

func get_random_starting_points() -> Array[int] :
	var y_coordinates : Array[int]
	var unique_starting_points : int = 0
	
	while unique_starting_points < 2:
		unique_starting_points = 0
		y_coordinates = []
		
		for i in PATHS:
			var starting_point : int = randi_range(0, GRID_WIDTH -1)
			if ! y_coordinates.has(starting_point):
				unique_starting_points +=1
			
			y_coordinates.append(starting_point)

	return y_coordinates

func setup_connection(i : int, j : int) -> int : 
	var next_district : DistrictsData
	var current_district : DistrictsData = map_data[i][j] as DistrictsData
	
	@warning_ignore("unassigned_variable")
	while !next_district or should_cross_existing_path(i,j,next_district):
		var random_j : int = clampi(randi_range(j - 1, j + 1), 0, GRID_WIDTH - 1)
		next_district = map_data[i + 1][random_j]
	
	current_district.next_districts.append(next_district)
	
	return next_district.column #or random_j

func should_cross_existing_path(i : int, j : int, district : DistrictsData) -> bool :
	var left_neighbour : DistrictsData
	var right_neighbour : DistrictsData
	
	if j > 0 :
		left_neighbour = map_data[i][j-1]
	
	if j < GRID_WIDTH -1 :
		right_neighbour = map_data[i][j+1]
	
	if right_neighbour and district.column > j:
		for next_district : DistrictsData in right_neighbour.next_districts:
			if next_district.column < district.column:
				return true
	
	if left_neighbour and district.column < j:
		for next_district : DistrictsData in left_neighbour.next_districts:
			if next_district.column > district.column:
				return true
	
	return false

func setup_final_district() -> void : 
	var middle : int = floori(GRID_WIDTH * 0.5)
	var final_district : DistrictsData = map_data[STEPS - 1][middle] as DistrictsData
	
	for j in GRID_WIDTH:
		var current_district : DistrictsData = map_data[STEPS - 2][j] as DistrictsData
		if current_district.next_districts:
			current_district.next_districts = [] as Array[DistrictsData]
			current_district.next_districts.append(final_district)

	final_district.type = DistrictsData.types.FINAL

func setup_random_district_weights() -> void : 
	random_districts_weights = DISTRICT_WEIGHTS_BY_BIOME[GameMaster.current_biome]
	random_districts_total_weights = 0

	for weight : int in random_districts_weights.values():
		random_districts_total_weights += weight

func setup_district_types() -> void : 
	#1 first district is always a parking (no mission)
	for district : DistrictsData in map_data[0]:
		if district.next_districts.size() > 0 :
			district.type = DistrictsData.types.ARENA
	
	#2 second district is always a mission (new survivor to save)
	for district : DistrictsData in map_data[1]:
		if district.next_districts.size() > 0 :
			district.type = DistrictsData.types.SURVIVOR
			
	#3 last district before boss is always a garage
	for district : DistrictsData in map_data[STEPS - 2]:
		if district.next_districts.size() > 0 :
			district.type = DistrictsData.types.GARAGE
			
	# rest of the districts
	for current_step : Array in map_data:
		for district : DistrictsData in current_step:
			for next_district : DistrictsData in district.next_districts:
				if next_district.type == DistrictsData.types.N_A:
					set_district_type_randomly(next_district)

func set_district_type_randomly(district_to_set : DistrictsData) -> void : 
	const MAX_ATTEMPTS : int = 32
	var type_candidate : DistrictsData.types = DistrictsData.types.ARENA

	for attempt in MAX_ATTEMPTS:
		type_candidate = get_random_district_type_by_weight()

		var is_garage : bool = type_candidate == DistrictsData.types.GARAGE
		var is_shop : bool = type_candidate == DistrictsData.types.SHOP  # <- corrigé
		var has_garage_parent : bool = district_has_parent_of_type(district_to_set, DistrictsData.types.GARAGE)
		var has_shop_parent : bool = district_has_parent_of_type(district_to_set, DistrictsData.types.SHOP)

		var garage_below_3 : bool = is_garage and district_to_set.row < 2
		var consecutive_garage : bool = is_garage and has_garage_parent
		var consecutive_shop : bool = is_shop and has_shop_parent
		var garage_2_steps_before_final : bool = is_garage and district_to_set.row == STEPS - 2

		if not (garage_below_3 or consecutive_garage or consecutive_shop or garage_2_steps_before_final):
			break

	district_to_set.type = type_candidate

func district_has_parent_of_type(district : DistrictsData, type : DistrictsData.types) -> bool:
	var parents : Array[DistrictsData] = []
	#left parent
	if district.column > 0 and district.row > 0:
		var parent_candidate : DistrictsData = map_data[district.row - 1][district.column - 1] as DistrictsData
		if parent_candidate.next_districts.has(district):
			parents.append(parent_candidate)
			
	
	#right parent
	if district.column < GRID_WIDTH - 1  and district.row > 0:
		var parent_candidate : DistrictsData = map_data[district.row - 1][district.column + 1] as DistrictsData
		if parent_candidate.next_districts.has(district):
			parents.append(parent_candidate)
			
	#below parent
	if  district.row > 0:
		var parent_candidate : DistrictsData = map_data[district.row - 1][district.column] as DistrictsData
		if parent_candidate.next_districts.has(district):
			parents.append(parent_candidate)
	
	for parent : DistrictsData in parents:
		if parent.type == type:
			return true
	
	return false

func get_random_district_type_by_weight() -> DistrictsData.types :
	var roulette : int = randi() % random_districts_total_weights
	var accumulator : int = 0

	for type : DistrictsData.types in random_districts_weights:
		accumulator += random_districts_weights[type]
		if roulette < accumulator:
			return type

	return DistrictsData.types.ARENA

func _on_next_day()-> void : 
	steps_reached += 1
	emit_signal("new_step_reached",steps_reached)
	
func unload()-> void : 
	steps_reached = 0
	map_data.clear()
	current_map_data.clear()
