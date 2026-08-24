extends Node

enum DIFFICULTIES {
	EASY,
	NORMAL,
	HARD
}

enum BIOMES {
	CITY,
	COUNTRYSIDE,
	DESERT,
	HARBOR
	}

var current_biome : BIOMES = BIOMES.CITY

var DIFFICULTIES_MOD : Dictionary[DIFFICULTIES,float] = {
	DIFFICULTIES.EASY : 0.8,
	DIFFICULTIES.NORMAL : 1.0,
	DIFFICULTIES.HARD : 1.25
}

var difficulty : DIFFICULTIES = DIFFICULTIES.NORMAL

var difficulty_mod : float = DIFFICULTIES_MOD[difficulty]

enum GAME_MODES {
	DEV,
	BUILD,
	RELEASE,
	GOD,
	SANDBOX,
	DEBUG
}

var game_mode : GAME_MODES

func _ready() -> void:
	game_mode = GAME_MODES.DEBUG

func is_debug() -> bool:
	return game_mode == GAME_MODES.DEBUG
