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

func load_level(scene : SCENES) -> void:
	previous_scene = current_scene
	current_scene = scene
	print("previous scene : ", SCENES.keys()[previous_scene]," / current scene : ", SCENES.keys()[current_scene])
	get_tree().call_deferred("change_scene_to_file", scenes_uid[scene])

func load_district(loading_district : DistrictsData) -> void : 
	previous_scene = SCENES.ROADMAP
	get_tree().call_deferred("change_scene_to_file", districts_scenes[loading_district.type])
	
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
