extends Control

func _ready() -> void:
	if ShopManager.apply_discount :
		queue_redraw()

func _draw() -> void:
	draw_line(
		Vector2(0,size.y),
		Vector2(size.x,0),
		Color.RED,
		2.0,
		true
	)
	
