extends Node

const Y_DIST : int = 88
const X_DIST : int = 128
const DIST_RANDOMNESS : int = 24
const STEPS : int = 8
const GRID_WIDTH : int = 7
const PATHS : int = 5

var starting_district_type : DistrictsData.types = DistrictsData.types.BANK

const SHOP_MIN_ROW : int = 3
const SHOP_MAX_ROW : int = STEPS - 3

var start_column : int = floori(GRID_WIDTH * 0.5)

const DISTRICT_WEIGHTS_BY_BIOME : Dictionary = {
	GameMaster.BIOMES.CITY : {
		DistrictsData.types.ARENA : 3,
		DistrictsData.types.HIGHWAY : 1,
		DistrictsData.types.SURVIVOR : 2,
		DistrictsData.types.EVENT : 1,
		DistrictsData.types.BANK : 3,
		DistrictsData.types.CAR_REPAIR : 2,
		DistrictsData.types.GUNSMITH : 3,
		DistrictsData.types.SUPERMARKET : 1,
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
		DistrictsData.types.CAR_REPAIR : 2,
		DistrictsData.types.SUPERMARKET : 1,
		DistrictsData.types.GUNSMITH : 2,
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
		DistrictsData.types.CAR_REPAIR : 2,
		DistrictsData.types.SUPERMARKET : 1,
		DistrictsData.types.GUNSMITH : 1,
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
		DistrictsData.types.CAR_REPAIR : 2,
		DistrictsData.types.SUPERMARKET : 1,
		DistrictsData.types.GUNSMITH : 2,
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
const GUNSMITH_DISTRICTS_WEIGHT : float = 2.0
const CARDEALER_DISTRICTS_WEIGHT : float = 2.0
const SUPERMARKET_DISTRICTS_WEIGHT : float = 2.0
const BANK_DISTRICTS_WEIGHT : float = 2.0
const CAR_REPAIR_DISTRICTS_WEIGHT : float = 2.0
const EVENT_DISTRICTS_WEIGHT : float = 3.0

var steps_reached : int = 0
var current_map_data : Array[Array]
var last_district : DistrictsData


signal new_step_reached(new_step : int)
var map_data : Array[Array] #Grid is an array of steps which are array of districts
var selected_districts : Array[DistrictsData]

func _ready() -> void:
	SignalManager.next_day.connect(_on_next_day)

func generate_map(_biome : GameMaster.BIOMES = GameMaster.current_biome) -> Array[Array] :
	map_data = generate_initial_grid()

	var first_columns : Array[int] = setup_starting_connections()

	for j : int in first_columns:
		var current_j : int = j
		for i : int in range(1, STEPS - 1):
			current_j = setup_connection(i, current_j)

	setup_final_district()
	setup_random_district_weights()
	setup_district_types()
	enforce_shop_on_every_path()

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

func setup_starting_connections() -> Array[int] :
	var root_district : DistrictsData = map_data[0][start_column] as DistrictsData
	var candidates : Array[int] = []

	# the root can only branch on its 3 direct neighbours (±1 column rule)
	for offset : int in [-1, 0, 1]:
		var candidate : int = clampi(start_column + offset, 0, GRID_WIDTH - 1)
		if not candidates.has(candidate):
			candidates.append(candidate)

	var columns : Array[int] = []

	# one path per candidate first, so the root always branches
	for candidate : int in candidates:
		if columns.size() >= PATHS:
			break
		columns.append(candidate)

	# remaining paths are spread randomly over the same candidates
	while columns.size() < PATHS:
		columns.append(candidates[randi() % candidates.size()])

	for column : int in columns:
		var next_district : DistrictsData = map_data[1][column] as DistrictsData
		if not root_district.next_districts.has(next_district):
			root_district.next_districts.append(next_district)

	return columns

func setup_connection(i : int, j : int) -> int : 
	var next_district : DistrictsData
	var current_district : DistrictsData = map_data[i][j] as DistrictsData
	
	@warning_ignore("unassigned_variable")
	while !next_district or should_cross_existing_path(i,j,next_district):
		var random_j : int = clampi(randi_range(j - 1, j + 1), 0, GRID_WIDTH - 1)
		next_district = map_data[i + 1][random_j]
	
	# two paths can walk through the same district : avoid duplicated edges
	if not current_district.next_districts.has(next_district):
		current_district.next_districts.append(next_district)
	
	return next_district.column

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
	#1 single starting district
	var root_district : DistrictsData = map_data[0][start_column] as DistrictsData
	root_district.type = starting_district_type
	
	#2 second district is always a mission (new survivor to save)
	for district : DistrictsData in map_data[1]:
		if district.next_districts.size() > 0 :
			district.type = DistrictsData.types.SURVIVOR

	#3 TEST third district is always a mission (new survivor to save)
	for district : DistrictsData in map_data[2]:
		if district.next_districts.size() > 0 :
			district.type = DistrictsData.types.SURVIVOR

	#4 last district before boss is always a garage
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
		var is_shop : bool = type_candidate == DistrictsData.types.SHOP
		var has_garage_parent : bool = district_has_parent_of_type(district_to_set, DistrictsData.types.GARAGE)
		var has_shop_parent : bool = district_has_parent_of_type(district_to_set, DistrictsData.types.SHOP)

		var garage_below_3 : bool = is_garage and district_to_set.row < 2
		var consecutive_garage : bool = is_garage and has_garage_parent
		var consecutive_shop : bool = is_shop and has_shop_parent
		var garage_before_garage_step : bool = is_garage and district_to_set.row == STEPS - 3
		var shop_too_early : bool = is_shop and district_to_set.row < SHOP_MIN_ROW

		if not (garage_below_3 or consecutive_garage or consecutive_shop or garage_before_garage_step or shop_too_early):
			break

	# hard rule : STEPS-2 is always a garage, so STEPS-3 never is
	if type_candidate == DistrictsData.types.GARAGE and district_to_set.row == STEPS - 3:
		type_candidate = DistrictsData.types.CAR_REPAIR

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

# Every path from the root to the boss must contain a shop.
# Greedy set cover : the district shared by the most uncovered paths wins.
func enforce_shop_on_every_path() -> void :
	var uncovered : Array[Array] = []

	for path : Array in collect_all_paths():
		if not path_has_shop(path):
			uncovered.append(path)

	var strict : bool = true

	while not uncovered.is_empty():
		var best_district : DistrictsData = null
		var best_score : int = 0

		for path : Array in uncovered:
			for district : DistrictsData in path:
				if not can_become_shop(district, strict):
					continue

				var score : int = 0
				for other_path : Array in uncovered:
					if other_path.has(district):
						score += 1

				if score > best_score:
					best_score = score
					best_district = district

		if best_district == null:
			# no slot left : drop the "no two shops in a row" rule and retry once
			if strict:
				strict = false
				continue
			push_warning("RoadMap : no valid shop slot for %d path(s)" % uncovered.size())
			break

		best_district.type = DistrictsData.types.SHOP
		strict = true

		var still_uncovered : Array[Array] = []
		for path : Array in uncovered:
			if not path.has(best_district):
				still_uncovered.append(path)

		uncovered = still_uncovered


func can_become_shop(district : DistrictsData, strict : bool) -> bool :
	if district.row < SHOP_MIN_ROW or district.row > SHOP_MAX_ROW:
		return false

	if district.type == DistrictsData.types.SHOP:
		return false

	if not strict:
		return true

	if district_has_parent_of_type(district, DistrictsData.types.SHOP):
		return false

	for next_district : DistrictsData in district.next_districts:
		if next_district.type == DistrictsData.types.SHOP:
			return false

	return true


func path_has_shop(path : Array) -> bool :
	for district : DistrictsData in path:
		if district.type == DistrictsData.types.SHOP:
			return true

	return false


# Depth first walk : every root-to-leaf route of the graph
func collect_all_paths() -> Array[Array] :
	var result : Array[Array] = []
	var first_path : Array[DistrictsData] = [map_data[0][start_column] as DistrictsData]
	var stack : Array[Array] = [first_path]

	while not stack.is_empty():
		var path : Array[DistrictsData] = stack.pop_back()
		var last_district : DistrictsData = path[path.size() - 1]

		if last_district.next_districts.is_empty():
			result.append(path)
			continue

		for next_district : DistrictsData in last_district.next_districts:
			var new_path : Array[DistrictsData] = path.duplicate()
			new_path.append(next_district)
			stack.append(new_path)

	return result



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
