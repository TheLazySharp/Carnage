extends Node
## Survivors: meta unlocks (known / locked) and the current run (frozen pool, on board)

##preload ressources array
const ALL_SURVIVORS : Array = [
	preload("uid://dxhcqb7igjvjw"), #LARA
	preload("uid://b5ctlqm42kkmh"), #JAVIER
	preload("uid://co2hy6ybsg7b6"), #BORIS
	preload("uid://b6nh0gs2w1hog"), #LEO
	preload("uid://c4cxif75gn4yr"), #VIKTOR
	#preload("uid://d3q6e2ttbedxt"), #MARINA
]

# ---- META (kept between runs) ----
var locked_survivors : Array[SurvivorData] = []    # not available at the start of the game: unlocked by saving them on the road
var known_survivors : Array[SurvivorData] = []     # available to start a run with (all survivors minus the locked ones)
var next_survivor_to_unlock : SurvivorData = null  # locked survivor added to the run pool, unlocked when saved

# ---- RUN (reset at each new run) ----
var run_pool : Array[SurvivorData] = []            # frozen at run start: survivors that can be met on the road
var on_board_survivors : Array[SurvivorData] = []  # in the car ([0] = driver)
var next_spawned_survivor : SurvivorData = null    # survivor of the district selected on the roadmap

@warning_ignore("unused_signal")
signal portrait_hovered(id : int)
@warning_ignore("unused_signal")
signal picked_up_survivor(new_survivor : SurvivorData)
@warning_ignore("unused_signal")
signal in_game_survivor_queuefree


func _ready() -> void:
	SignalManager.district_survivor.connect(_on_district_selected)
	reload()


## Starting survivor chosen: the run pool is frozen here (shuffled once)
func select_survivor(new_survivor : SurvivorData) -> void:
	if !on_board_survivors.is_empty() or !known_survivors.has(new_survivor):
		return
	on_board_survivors.append(new_survivor)
	run_pool.clear()
	for survivor : SurvivorData in known_survivors:
		if survivor != new_survivor:
			run_pool.append(survivor)
	if next_survivor_to_unlock != null and !run_pool.has(next_survivor_to_unlock):
		run_pool.append(next_survivor_to_unlock)
	run_pool.shuffle()


## No survivor on the map once the car is full, or when nobody is left to meet
func can_offer_survivor() -> bool:
	return !run_pool.is_empty() and on_board_survivors.size() < CarManager.selected_car.seats


func _on_survivor_picked_up(new_survivor : SurvivorData) -> void:
	# Double trigger guard: the weapon must never be equipped twice
	if new_survivor == null or on_board_survivors.has(new_survivor):
		return
	# Saving a locked survivor unlocks it for the next runs
	if locked_survivors.has(new_survivor):
		locked_survivors.erase(new_survivor)
		known_survivors.append(new_survivor)
		if next_survivor_to_unlock == new_survivor:
			next_survivor_to_unlock = null
	run_pool.erase(new_survivor)
	on_board_survivors.append(new_survivor)
	WeaponsManager.equip_weapon(new_survivor.weapon)
	# Placed on maneuvers at the end of the raid, never during it
	LoadoutManager.add_pending_weapon(new_survivor.weapon)


func _on_district_selected(next_survivor : SurvivorData) -> void:
	next_spawned_survivor = next_survivor


## Known = every survivor that is not locked (all of them while locked_survivors is empty)
func refresh_known_survivors() -> void:
	known_survivors.clear()
	for survivor : SurvivorData in ALL_SURVIVORS:
		if !locked_survivors.has(survivor):
			known_survivors.append(survivor)


## Resets the run only: the meta lists (locked, next to unlock) are kept
func reload() -> void:
	run_pool.clear()
	on_board_survivors.clear()
	next_spawned_survivor = null
	refresh_known_survivors()


func unload() -> void:
	reload()
