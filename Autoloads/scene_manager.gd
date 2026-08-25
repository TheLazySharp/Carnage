extends Node



enum SCENES {
	MAIN_MENU,
	CAR_SELECTION,
	GAME_OVER,
	START_INTRO,
	END_DAY,
	GARAGE,
	COMMANDS,
	MISSIONS,
	SURVIVORS,
	ROADMAP,
	RAID,
	SHOP,
	HOME,
	CAR_LEVELUP,
	GOD_MOD_TRAINING,
	RACE,
	SANDBOX
}

var scenes_uid: Dictionary[SCENES,String] = {
	SCENES.MAIN_MENU : "uid://gmjjc1vmgcds",
	SCENES.CAR_SELECTION : "uid://b0ibe3gvcqm4q",
	SCENES.GAME_OVER : "uid://c6ue1qnj30p5b",
	SCENES.START_INTRO : "uid://dqfr2nck8fjao",
	SCENES.END_DAY : "uid://dkpvtoel7hhai",
	SCENES.GARAGE : "uid://cs311xlcqlrt0",
	#"Tuto" : "uid://ci6t4884t7q6r",
	#"Level01" : "uid://c6msxridefxxd",
	#"LuckyCharms" : "uid://ch2rp03kbdyg7",
	SCENES.COMMANDS : "uid://dayxnnf2ndx5c",
	SCENES.MISSIONS : "uid://dc6hb14w0yref",
	SCENES.SURVIVORS : "uid://cui5s6rmjs40o",
	SCENES.ROADMAP : "uid://dsn18jy5k2in8",
	SCENES.SHOP : "uid://cvogwsu4e47t0",
	SCENES.HOME : "uid://cvkxdbb1u1tw0",
	SCENES.CAR_LEVELUP : "uid://cum1kdgu8a1di",
	SCENES.GOD_MOD_TRAINING : "uid://df565yrwfqn1v",
	SCENES.RAID : "uid://df565yrwfqn1v",
	#SCENES.GOD_MOD_TRAINING : "uid://dyy6lm0fy0oqs"
	SCENES.RACE : "uid://cftayor44iqic",
	SCENES.SANDBOX : "uid://3akvde2gonk6"
}


var districts_scenes : Dictionary[DistrictsData.types,String] = {
	DistrictsData.types.GARAGE :"uid://df565yrwfqn1v",
	DistrictsData.types.SURVIVOR :"uid://df565yrwfqn1v",
	DistrictsData.types.ARENA :"uid://df565yrwfqn1v",
	DistrictsData.types.HIGHWAY :"uid://df565yrwfqn1v",
	DistrictsData.types.GUNSHOP :"uid://df565yrwfqn1v",
	DistrictsData.types.CARDEALER :"uid://df565yrwfqn1v",
	DistrictsData.types.FINAL :"uid://df565yrwfqn1v",
	DistrictsData.types.BANK :"uid://df565yrwfqn1v",
	DistrictsData.types.CAR_REPAIR :"uid://df565yrwfqn1v",
	DistrictsData.types.EVENT :"uid://df565yrwfqn1v",
	DistrictsData.types.SHOP :"uid://cvogwsu4e47t0"
}

var current_scene : SCENES = SCENES.MAIN_MENU
var previous_scene : SCENES 


#TEST = true
var tuto_completed: bool = false
var commands_displayed : bool = false

var ready_go_timer: float = 2.0

var commands_from_menu : bool = false

var default_loading_message : String = "Designing the district, please wait"

## Safety net if map_generated never fires (broken pass, scene without map)
const OVERLAY_TIMEOUT : float = 30.0
var _level_ready : bool = false


func _ready() -> void:
	SignalManager.map_generated.connect(_on_map_generated)

func load_level(scene : SCENES, loading_message : String = "") -> void:
	previous_scene = current_scene
	current_scene = scene
	print("previous scene : ", SCENES.keys()[previous_scene], " / current scene : ", SCENES.keys()[current_scene])
	await _change_scene(scenes_uid[scene], "")


func load_district(loading_district : DistrictsData, loading_message : String = "") -> void:
	previous_scene = SCENES.ROADMAP
	current_scene = SCENES.RAID
	await _change_scene(districts_scenes[loading_district.type], default_loading_message)


## The overlay is driven by the DESTINATION, never by the caller: only a scene
## implementing build_level() needs one, and that is tested after loading.
func _change_scene(path : String, message : String) -> void:
	# Overlay is opt-in: only a caller that actually passes a message gets one.
	# No default_loading_message fallback here -- that fallback is what made
	# every single scene show the overlay.
	var use_overlay : bool = not message.is_empty()
	if use_overlay:
		await LoadingScreen.open(message)

	var real_path : String = path
	if path.begins_with("uid://"):
		var uid : int = ResourceUID.text_to_id(path)
		if not ResourceUID.has_id(uid):
			push_error("[SceneManager] unknown UID: " + path)
			if use_overlay:
				await LoadingScreen.close()
			return
		real_path = ResourceUID.get_id_path(uid)

	ResourceLoader.load_threaded_request(real_path, "PackedScene")
	while true:
		var status : int = ResourceLoader.load_threaded_get_status(real_path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			push_error("[SceneManager] load failed (status %d): %s" % [status, real_path])
			if use_overlay:
				await LoadingScreen.close()
			return
		await get_tree().process_frame

	var packed : PackedScene = ResourceLoader.load_threaded_get(real_path) as PackedScene
	get_tree().change_scene_to_packed(packed)

	if use_overlay:
		_close_overlay_when_generated()


func _close_overlay_when_generated() -> void:
	# map_generated is the only reliable "level is ready" event: current_scene
	# is unusable right after change_scene_to_packed, it goes through null
	# while the swap is flushed.
	_level_ready = false
	var elapsed : float = 0.0
	while not _level_ready and elapsed < OVERLAY_TIMEOUT:
		elapsed += get_process_delta_time()
		await get_tree().process_frame
	if not _level_ready:
		push_warning("[SceneManager] overlay timeout, closing anyway")
	await RenderingServer.frame_post_draw
	await LoadingScreen.close()


func _on_map_generated(_data : MapData) -> void:
	_level_ready = true


func unload_game() -> void:
	XPManager.unload()
	WeaponsManager.unload()
	InventoryManager.unload()
	StatsManager.unload()
	CharmsManager.unload()
	TimeManager.unload()
	RoadMapManager.unload()
	SurvivorsManager.unload()
	ShopManager.unload()
	BuildingsManager.unload()
	jobs_manager.unload()
