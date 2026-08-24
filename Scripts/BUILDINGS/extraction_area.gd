extends Area2D
## Extraction trigger, placed from the generated map: the main artery row
## changes with every seed.

## Depth along the road, in cells. 4 leaves a wide anti-tunneling margin.
@export var depth_cells : int = 4

@onready var zone: ColorRect = $"Warp Shape/ColorRect"
@onready var warp_shape: CollisionShape2D = $"Warp Shape"


func _ready() -> void:
	SignalManager.map_generated.connect(_on_map_generated)
	SignalManager.day_time_end.connect(_on_day_timer_ended)



func _on_day_timer_ended(timer_ended : bool) -> void : 
	if timer_ended:
		zone.show()
		warp_shape.set_deferred("disabled",false)


func _on_map_generated(data : MapData) -> void:
	zone.hide()
	warp_shape.set_deferred("disabled",true)
	var cell : float = float(data.cell_size)
	#var rect : RectangleShape2D = RectangleShape2D.new()
	## Full artery width across, so the player cannot miss it sideways
	warp_shape.shape.size = Vector2(float(depth_cells) * cell, data.artery_width_px())
	#shape.shape = rect
	# Just inside the right border, centred on the main artery
	global_position = Vector2(
			float(data.map_size_cells.x) * cell - warp_shape.shape.size.x * 0.5,
			float(data.artery_y) * cell)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		#animation_player.play("closing")
		StatsManager.total_drift = body.get_node("DriftManager").total_drift_points
		await get_tree().create_timer(2).timeout
		SignalManager.emit_signal("next_day")
		SceneManager.load_level(SceneManager.SCENES.CAR_LEVELUP)
