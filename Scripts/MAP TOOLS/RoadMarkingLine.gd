@tool
extends Resource
class_name RoadMarkingLine

@export var color: Color = Color.WHITE:
	set(value):
		color = value
		emit_changed()

@export var thickness: int = 3:
	set(value):
		thickness = max(value, 1)
		emit_changed()

@export var dash_length: int = 20:
	set(value):
		dash_length = max(value, 1)
		emit_changed()

@export var gap_length: int = 12:
	set(value):
		gap_length = max(value, 0)
		emit_changed()

@export var perpendicular_offset: float = 0.0:
	set(value):
		perpendicular_offset = value
		emit_changed()

## Finesse du suivi de la courbe à l'intérieur d'un tiret, en pixels virtuels.
## Plus petit = suit mieux les virages serrés, plus de calcul.
@export var curve_sample_step: int = 2:
		set(value):
			curve_sample_step = max(value, 1)
			emit_changed()

@export_group("Usure")
@export var enable_wear: bool = false:
	set(value):
		enable_wear = value
		emit_changed()
@export var wear_spacing: float = 2.0:
	set(value):
		wear_spacing = max(value, 0.5)
		emit_changed()
@export_range(0.0, 1.0, 0.01) var wear_density: float = 0.3:
	set(value):
		wear_density = clamp(value, 0.0, 1.0)
		emit_changed()
@export var wear_bite_min: int = 1:
	set(value):
		wear_bite_min = min(value, wear_bite_max)
		emit_changed()
@export var wear_bite_max: int = 3:
	set(value):
		wear_bite_max = max(value, wear_bite_min)
		emit_changed()

@export var line_seed: int = 0:
	set(value):
		line_seed = value
		emit_changed()
		
@export_range(0.0, 0.2, 0.001) var interior_wear_density: float = 0.015:
		set(value):
			interior_wear_density = clamp(value, 0.0, 1.0)
			emit_changed()
@export_range(0.0, 1.0, 0.01) var interior_wear_pair_chance: float = 0.3:
		set(value):
			interior_wear_pair_chance = clamp(value, 0.0, 1.0)
			emit_changed()
