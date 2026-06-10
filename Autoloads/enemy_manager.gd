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
