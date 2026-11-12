extends Node
## Survivors: meta unlocks (known / locked) and the current run (frozen pool, on board)

const DOMINIC = preload("uid://b6nh0gs2w1hog")
const FREDRIK = preload("uid://co2hy6ybsg7b6")
const JAVIER = preload("uid://b5ctlqm42kkmh")
#const LARA = preload("uid://dxhcqb7igjvjw")
const MARINA = preload("uid://d3q6e2ttbedxt")
const PETER = preload("uid://dmkjdk1jmfb4v")
const CLEM = preload("uid://c4cxif75gn4yr")
const ALMA = preload("uid://dvuusxwhxeiiy")
const FRANCK = preload("uid://dx32ydmg6le5f")




##preload ressources array
const ALL_SURVIVORS : Array = [
	CLEM,
	FREDRIK,
	JAVIER,
	#LARA,
	DOMINIC,
	PETER,
	MARINA,
	ALMA,
	FRANCK,
]

# ---- META (kept between runs) ----
var locked_survivors : Array[SurvivorData] = []    # not available at the start of the game: unlocked by saving them on the road
var known_survivors : Array[SurvivorData] = []     # available to start a run with (all survivors minus the locked ones)
var next_survivor_to_unlock : SurvivorData = null  # locked survivor added to the run pool, unlocked when saved
var administration_done : bool = false


# ---- RUN (reset at each new run) ----
var run_pool : Array[SurvivorData] = []            # frozen at run start: survivors that can be met on the road
var on_board_survivors : Array[SurvivorData] = []  # in the car ([0] = driver)
var next_spawned_survivor : SurvivorData = null    # survivor of the district selected on the roadmap
var rescued_survivor : SurvivorData = null
var starting_job : JobData = null

@warning_ignore("unused_signal")
signal portrait_hovered(id : int)
@warning_ignore("unused_signal")
signal picked_up_survivor(new_survivor : SurvivorData)
@warning_ignore("unused_signal")
signal in_game_survivor_queuefree


func _ready() -> void:
	SignalManager.district_survivor.connect(_on_district_selected)
	SignalManager.sandbox_mode.connect(_on_sandbox_mode)
	SignalManager.run_started.connect(_on_run_started)
	if !administration_done:
		administration_done = true
		survivor_admninistration()
	reload()


## Starting survivor chosen: the run pool is frozen here (shuffled once)
func select_survivor(new_survivor : SurvivorData) -> void:
	if !on_board_survivors.is_empty() or !known_survivors.has(new_survivor):
		return
	on_board_survivors.append(new_survivor)
	starting_job = new_survivor.job_ressource
	run_pool.clear()
	
	if !known_survivors.is_empty():
		for survivor : SurvivorData in known_survivors:
			if survivor != new_survivor:
				run_pool.append(survivor)
	if !locked_survivors.is_empty():
		for survivor : SurvivorData in locked_survivors:
			if survivor != new_survivor:
				run_pool.append(survivor)
	if next_survivor_to_unlock != null and !run_pool.has(next_survivor_to_unlock):
		run_pool.append(next_survivor_to_unlock)
	run_pool.shuffle()

func survivor_admninistration() -> void : 
	known_survivors.append(PETER)
	known_survivors.append(MARINA)
	known_survivors.append(JAVIER)
	known_survivors.append(CLEM)
	known_survivors.append(FREDRIK)
	#known_survivors.append(LARA)
	known_survivors.append(DOMINIC)
	known_survivors.append(ALMA)
	known_survivors.append(FRANCK)
	
	#locked_survivors.append(FREDRIK)
	#locked_survivors.append(LARA)
	#locked_survivors.append(JAVIER)
	#locked_survivors.append(DOMINIC)
	#locked_survivors.append(PETER)
	#locked_survivors.append(ALMA)
	#locked_survivors.append(FRANCK)

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


## Saved on the road: on board right away (weapon placed at the end of the raid),
## codec bubble now, recap screen after the raid (his job starts there)
func rescue(new_survivor : SurvivorData) -> void:
	if new_survivor == null or on_board_survivors.has(new_survivor):
		return
	_on_survivor_picked_up(new_survivor)
	rescued_survivor = new_survivor
	SignalManager.survivor_rescued.emit(new_survivor)


## Recap screen validated: the rescued survivor job starts. Once only
func confirm_rescue() -> void:
	if rescued_survivor == null:
		return
	var job : JobData = rescued_survivor.job_ressource
	rescued_survivor = null
	JobsManager.activate_job(job)

## Run ready (roadmap or sandbox car selection): the starting survivor job starts, once
func _on_run_started() -> void:
	if starting_job == null:
		return
	JobsManager.activate_job(starting_job)
	starting_job = null

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
	rescued_survivor = null
	starting_job = null

func unload() -> void:
	reload()

func _on_sandbox_mode() -> void :
	for i in locked_survivors.size():
		if !known_survivors.has(locked_survivors[i]):
			known_survivors.append(locked_survivors[i])
