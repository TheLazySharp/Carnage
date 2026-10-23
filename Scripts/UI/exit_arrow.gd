extends Node2D
## Exit arrow: sits on the screen edge, pointing at the extraction zone while it is off screen

## Distance kept between the arrow and the screen edge (px, about half the arrow size)
@export var screen_margin : float = 48.0
## Direction the art points to: 0 if it points right, 90 if it points up
@export var art_rotation_offset_deg : float = 0.0

var target_position : Vector2 = Vector2.ZERO
var art_rotation_offset : float = 0.0
@onready var animated_arrow: AnimatedSprite2D = $AnimatedArrow


func _ready() -> void:
	art_rotation_offset = deg_to_rad(art_rotation_offset_deg)
	hide()
	# Nothing to compute until the exit opens
	set_process(false)
	SignalManager.exit_arrow_target.connect(_on_exit_arrow_target)


func _on_exit_arrow_target(p_target : Vector2) -> void:
	target_position = p_target
	set_process(true)
	animated_arrow.play("moving")


func _process(_delta : float) -> void:
	var viewport : Viewport = get_viewport()
	var screen_center : Vector2 = viewport.get_visible_rect().size * 0.5
	# World -> screen: the canvas transform holds the camera position and zoom
	var target_on_screen : Vector2 = viewport.get_canvas_transform() * target_position
	var half_extent : Vector2 = screen_center - Vector2(screen_margin, screen_margin)
	var offset : Vector2 = target_on_screen - screen_center
	# Exit visible on screen: no arrow needed
	if absf(offset.x) <= half_extent.x and absf(offset.y) <= half_extent.y:
		hide()
		return
	# Push the direction out to the screen edge, minus the margin
	var scale_x : float = half_extent.x / absf(offset.x) if offset.x != 0.0 else INF
	var scale_y : float = half_extent.y / absf(offset.y) if offset.y != 0.0 else INF
	position = screen_center + offset * minf(scale_x, scale_y)
	rotation = offset.angle() + art_rotation_offset
	show()
