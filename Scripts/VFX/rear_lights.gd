extends Node2D
## Tail light glow: soft additive halos that light up on braking and drifting.
## Drawn over the skid clouds, they tint the white smoke red

## HDR color (> 1 feeds the WorldEnvironment glow)
@export var glow_color : Color = Color(4.0, 0.25, 0.15, 1.0)
## Halo strength when not braking (0 = off)
@export_range(0.0, 1.0) var idle_intensity : float = 0.15
## Fade speeds (per second): quick on, slower off so the glow lingers in the smoke
@export var on_speed : float = 15.0
@export var off_speed : float = 5.0
## Optional: the small tail light ColorRects, brightened with the halos
@export var light_rects : Array[ColorRect] = []
@export var rect_lit_boost : float = 2.5
## Halo size when not braking, share of its size in the editor (1 = no size change)
@export_range(0.1, 1.0) var idle_scale_ratio : float = 0.5

var halo_base_scales : Array[Vector2] = []
var car : CharacterBody2D = null
var halos : Array[Sprite2D] = []
var intensity : float = -1.0  # -1 forces the first update


func _ready() -> void:
	car = owner as CharacterBody2D
	var additive : CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for child : Node in get_children():
		var halo : Sprite2D = child as Sprite2D
		if halo != null:
			halo.material = additive
			halos.append(halo)
			halo_base_scales.append(halo.scale)


func _process(delta : float) -> void:
	if car == null:
		return
	var lit : bool = car.braking or car.drifting or car.drift_manager.is_recovering()
	var target : float = 1.0 if lit else idle_intensity
	var speed : float = on_speed if target > intensity else off_speed
	var new_intensity : float = move_toward(maxf(intensity, 0.0), target, speed * delta)
	if new_intensity == intensity:
		return
	intensity = new_intensity
	var halo_color : Color = Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * intensity)
	var scale_ratio : float = lerpf(idle_scale_ratio, 1.0, intensity)
	for i : int in halos.size():
		halos[i].modulate = halo_color
		halos[i].scale = halo_base_scales[i] * scale_ratio
	var rect_mult : float = lerpf(1.0, rect_lit_boost, intensity)
	for rect : ColorRect in light_rects:
		rect.modulate = Color(rect_mult, rect_mult, rect_mult, 1.0)
		
	
