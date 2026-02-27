extends Node2D

@onready var ghost_sprite: Sprite2D = $GhostSprite

func _ready() -> void:
	if CarManager.selected_car:
		ghost_sprite.texture = CarManager.selected_car.car_sprite
	ghosting()



func _process(_delta: float) -> void:
	pass

func set_property(parent_pos : Vector2, parent_scale : Vector2, parent_rotation : float) -> void:
	position = parent_pos
	scale = parent_scale
	rotation = parent_rotation
	
func ghosting() -> void : 
	var tween_fade : Tween = get_tree().create_tween()
	tween_fade.tween_property(ghost_sprite, "self_modulate",Color(1.0, 1.0, 1.0, 0.0),0.75)
	await tween_fade.finished
	queue_free()
