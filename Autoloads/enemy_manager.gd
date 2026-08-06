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

var rotation_mode : Rotation_Mode = Rotation_Mode.CARDINAL_4
var life_progression_step : int = 10
var max_life_mod : Modifier

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
