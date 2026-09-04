extends Resource

class_name DistrictsData


enum types {
	N_A,
	ARENA,
	HIGHWAY,
	SURVIVOR,
	EVENT,
	SHOP,
	GARAGE,
	BANK,
	CAR_REPAIR,
	GUNSHOP,
	SUPERMARKET,
	CARDEALER,
	FINAL
	}

## Districts whose scene builds a procedural map. Everything else is a light
## Control scene (shop, garage, banque...) and must swap instantly.
## Type-based on purpose: RoadMapManager creates every district with
## DistrictsData.new(), so a per-resource flag never survives.
const MAP_TYPES : Array[int] = [
	types.ARENA,
	types.HIGHWAY,
	types.SURVIVOR,
	types.BANK,
	types.CAR_REPAIR,
	types.GUNSHOP,
	types.SUPERMARKET,
	types.CARDEALER,
	types.FINAL
]


func builds_map() -> bool:
	return MAP_TYPES.has(type)


@export var type : types
@export var icon : Texture2D
@export var row : int
@export var column : int
@export var position : Vector2
@export var next_districts : Array[DistrictsData]
@export var selected : bool = false

func _to_string() -> String:
	return "%s (%s)" % [column, types.keys()[type][0]] #return first letter of the enum key
