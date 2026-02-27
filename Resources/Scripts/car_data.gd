extends Resource

class_name CarData

@export var car_name : String

@export_group("DRIVING")
@export var base_acceleration := 300
@export var base_max_speed := 500
@export var friction := 500.0
@export var turn_speed := 3.2
@export var velocity_floor:= 50
@export var burnout_boost := 200

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
@export var base_max_life:= 250
@export var base_display_max_speed := 250
@export var base_dmg := 15


@export_group("AUDIO")
@export var start_engine_Sound: AudioStreamMP3

@export_group("VFX")
@export var car_sprite: Texture2D
#@export var car_explosion: SpriteFrames


var engine_lvl:=0
var turbo_lvl:=0
var shield_lvl:=0
var carbon_lvl:=0
var front_gear_lvl:=0
var tank_lvl:=0
var front_gear : FrontGearData
var tires : TiresData

var acceleration: int
var max_speed: int
var max_life: int
var display_max_speed: int
var dmg: int

#var acceleration = base_acceleration + carbon_lvl * 10 - shield_lvl * 5
#var max_speed = base_max_speed + engine_lvl * 10
#var max_life = base_max_life + shield_lvl * 5
#var display_max_speed = base_display_max_speed + engine_lvl * 5
#var dmg = base_dmg + shield_lvl * 5
