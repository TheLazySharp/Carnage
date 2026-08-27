@tool
extends Resource
class_name RoadWearLine

@export var textures : Array[Texture2D] = []:
	set(value):
		textures = value
		emit_changed()

## Décalage perpendiculaire du centre de cette ligne par rapport à l'axe du Path2D,
## en pixels virtuels (multiplié par pixel_size du RoadBrushPath2D parent).
@export var perpendicular_offset: float = 0.0:
	set(value):
		perpendicular_offset = value
		emit_changed()

@export var spacing: float = 3.0:
	set(value):
		spacing = max(value, 0.1)
		emit_changed()

## Variation aléatoire de la distance entre deux tentatives de spawn.
@export var spacing_jitter: float = 0.0:
	set(value):
		spacing_jitter = max(value, 0.0)
		emit_changed()

## Proportion moyenne de la longueur du Path2D couverte par cette ligne.
@export_range(0.0, 1.0, 0.01) var coverage_ratio: float = 0.6:
	set(value):
		coverage_ratio = clamp(value, 0.0, 1.0)
		emit_changed()

## Longueur moyenne d'une coupure, en pixels virtuels. Plus petit = coupures
## nombreuses et courtes ; plus grand = coupures rares et longues (à coverage_ratio égal).
@export var avg_gap_length: float = 20.0:
	set(value):
		avg_gap_length = max(value, 0.1)
		emit_changed()

@export var fade_start_length: float = 0.0:
	set(value):
		fade_start_length = max(value, 0.0)
		emit_changed()

@export var fade_end_length: float = 0.0:
	set(value):
		fade_end_length = max(value, 0.0)
		emit_changed()

@export_range(0.2, 5.0, 0.05) var fade_curve_power: float = 1.0:
	set(value):
		fade_curve_power = value
		emit_changed()

@export var constrain_rotation_90: bool = true:
	set(value):
		constrain_rotation_90 = value
		emit_changed()

@export var allow_flip: bool = true:
	set(value):
		allow_flip = value
		emit_changed()

@export var color: Color = Color.WHITE:
	set(value):
		color = value
		emit_changed()

@export var line_seed: int = 0:
	set(value):
		line_seed = value
		emit_changed()
