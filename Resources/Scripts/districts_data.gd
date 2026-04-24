extends Resource

class_name DistrictsData


enum types {N_A, PARKING, MISSION, GARAGE, BOSS, SHOP}

@export var type : types
@export var icon : Texture2D
@export var row : int
@export var column : int
@export var position : Vector2
@export var next_districts : Array[DistrictsData]
@export var selected : bool = false

func _to_string() -> String:
	return "%s (%s)" % [column, types.keys()[type][0]] #return first letter of the enum key
