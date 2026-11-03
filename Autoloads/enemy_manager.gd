extends Node

enum Enemy_Types {
	COMMON,
	COLOSS,
	TANK,
	FAST,
	LAUNCHER
}

const COMMON_ZOMBIE = preload("uid://c8whek5n8pers")
const COLOSS_ZOMBIE = preload("uid://dfk50o0utso3f")
const TANK_ZOMBIE = preload("uid://cdu4vgc1bsrud")

var Enemy_ressources : Dictionary = {
	Enemy_Types.COMMON : COMMON_ZOMBIE,
	Enemy_Types.COLOSS : COLOSS_ZOMBIE,
	Enemy_Types.TANK : TANK_ZOMBIE
}

enum Rotation_Mode {
	FREE_360,
	CARDINAL_4,
	CARDINAL_8
}


var rotation_mode : Rotation_Mode = Rotation_Mode.CARDINAL_8
var life_progression_step : int = 10
var max_life_mod : Modifier

## Lethal damage types: each one maps to a death animation state ("dead" for DEFAULT, "dead_<name>" otherwise).
## Only add new values at the END: exported enums are saved as ints in .tres files.
enum DEATH_TYPES {
	DEFAULT,
	CAR,
	KNOCKED,
	SLICE,
	EXPLOSION,
	SHOT,
	SPLAT,
	BURN,
	POISON,
	SHOCK
}

var death_state_names: PackedStringArray = build_death_state_names() # index = Death_Types

enum Status { NONE, BURN, POISON, SHOCK, FREEZE }

const STATUS_TICK : Dictionary[Status, float] = {
	Status.BURN: 0.25,
	Status.POISON: 0.75,
}
## Death animation when a status tick kills
const STATUS_DEATH : Dictionary[Status, DEATH_TYPES] = {
	Status.BURN: DEATH_TYPES.BURN,
	Status.POISON: DEATH_TYPES.POISON,
	Status.SHOCK: DEATH_TYPES.SHOCK
}

## Enemy tint while the status is active (NONE = back to normal)
const STATUS_COLORS : Dictionary[Status, Color] = {
	Status.NONE: Color.WHITE,
	Status.BURN: Color(1.0, 0.55, 0.3),
	Status.POISON: Color(0.55, 1.0, 0.4),
	Status.SHOCK: Color(1.0, 1.0, 0.45),
	Status.FREEZE: Color(0.55, 0.8, 1.0),
}


func build_death_state_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for key: String in DEATH_TYPES.keys():
		names.append("dead" if key == "DEFAULT" else "dead_" + key.to_lower())
	return names


func get_death_state_name(death_type: DEATH_TYPES) -> String:
	return death_state_names[death_type]

func _ready() -> void:
	RoadMapManager.new_step_reached.connect(_on_next_day)


func _on_next_day(current_step : int) -> void :
	max_life_mod = Modifier.new(life_progression_step * current_step,Modifier.Type.FLAT,"enemies manager max life mod")


func get_rotation_snap_step() -> float:
	match rotation_mode:
		Rotation_Mode.CARDINAL_4:
			return PI * 0.5
		Rotation_Mode.CARDINAL_8:
			return PI * 0.25
	return 0.0
