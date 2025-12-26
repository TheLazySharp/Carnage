extends Control

@onready var drop: TileMapLayer = $"../../Land_layers/Drop"
var drop_tile_OK := false
var is_drop_completed := false

signal drop_tile(drop_tile_OK : bool)

func _ready() -> void:
	drop.drop_completed.connect(update_drop_completion_status)

func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:	
	return true

func _drop_data(_at_position: Vector2, _data: Variant) -> void:
	if not drop_tile_OK:
		drop_tile_OK = true
		emit_signal("drop_tile",drop_tile_OK)
		#print("Step 1 - data emite drop_tile is : ",drop_tile_OK)

	#or quantity -1

func update_drop_completion_status(drop_completed) -> void:
	is_drop_completed = drop_completed
	if is_drop_completed:
		drop_tile_OK = false
		emit_signal("drop_tile",drop_tile_OK)
		#print("Step 3 - data emite drop_tile is : ",drop_tile_OK)
