extends Resource

class_name CarData

@export var car_name : String

@export_group("DRIVING")
@export var acceleration := 300
@export var max_speed := 500
@export var friction := 500.0
@export var turn_speed := 3.2
@export var velocity_floor:= 50

@export_group("DRIFT")

@export var drift_grip := 0.015
@export var normal_grip := 0.18
@export var drift_turn_bonus := 3.2

@export var max_drift_damping := 3.5
@export var min_drift_speed := 150.0

@export var snap_grip := 0.75
@export var snap_speed := 8.0

@export_group("SKIDS")
@export var skid_spacing := 8.0
@export var skid_lifetime := 2.5
@export var skid_fade_speed := 1.5

@export_group("STATS")
@export var max_life:= 250
@export var display_max_speed := 250
@export var dmg := 15

@export_group("AUDIO")
@export var start_engine_Sound: AudioStreamMP3

@export_group("VFX")
@export var car_sprite: Texture2D
#@export var car_explosion: SpriteFrames
