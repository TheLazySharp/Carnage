extends Resource
class_name CarData

@export var car_name : String
@export var seats : int = 5


@export_group("MAIN STATS")
@export var base_acceleration := 300
@export var base_max_speed := 250
@export var base_max_life : int = 250
#@export var base_display_max_speed : int = 250
@export var base_dmg : int = 15
@export var base_dash_dmg_bonus : float = 1.0 #modifier in percent_mult = 100%
@export var base_nitro_up : int = 10
@export var base_collect_radius : float = 30
@export var base_drift_turn_bonus := 3.2
@export var base_dash_duration := 0.75
@export var base_max_fuel := 40


@export_group("DRIVING")
@export var friction := 500.0
@export var turn_speed := 3.2
@export var velocity_floor:= 50
@export var burnout_boost := 200
@export var dash_fuel_down := 10


@export_group("DRIFT")
@export var drift_grip := 0.015
@export var normal_grip := 0.18
@export var max_drift_damping := 3.5
@export var min_drift_speed := 150.0
@export var snap_grip := 0.75
@export var snap_speed := 8.0
@export var max_boost_gauge : int = 100 
var drifting : bool = false

@export_group("SKIDS")
@export var skid_spacing := 8.0
@export var skid_lifetime := 2.5
@export var skid_fade_speed := 1.5

@export_group("AUDIO")
@export var start_engine_Sound: AudioStreamMP3

@export_group("VFX")
@export var car_sprite: Texture2D
#@export var car_explosion: SpriteFrames


var engine_lvl: int = 0
var turbo_lvl: int = 0
var shield_lvl: int = 0
var carbon_lvl: int = 0
var tank_lvl: int = 0
var nitro_lvl: int = 0
var wheels_lvl: int = 0
var bumper_lvl: int = 0

# ------- STATS THAT CAN BE MODIFIED -----------

enum Car_Stats {
	N_A,
	ACCELERATION,
	MAX_SPEED,
	MAX_LIFE,
	DMG,
	DASH_DMG_BONUS,
	DASH_DURATION,
	NITRO_UP,
	COLLECT_RADIUS,
	DRIFT_TURN_BONUS,
	MAX_FUEL
}

enum Car_Upgrades {
	N_A,
	ENGINE,
	TURBO,
	SHIELD,
	CARBON,
	TANK,
	NITRO,
	WHEELS,
	BUMPER
}

var acceleration: Statistic
var max_speed: Statistic
var max_life: Statistic
#var display_max_speed: Statistic
var dmg: Statistic
var dash_dmg_bonus : Statistic #dmg during dash
var dash_duration : Statistic #dash duration
var nitro_up : Statistic #nitro gauge fill up speed
var collect_radius : Statistic
var drift_turn_bonus : Statistic
var max_fuel : Statistic

var stat_modifiers : Array[Modifier] = []
@warning_ignore("unused_signal")
signal stat_adjusted(stat : Statistic )
var current_life : int 
var current_fuel : int 

var invincible : bool = false

func init_stats() -> void:
	engine_lvl = 0
	turbo_lvl = 0
	shield_lvl = 0
	carbon_lvl = 0
	tank_lvl = 0
	nitro_lvl = 0
	wheels_lvl = 0
	bumper_lvl = 0
	
	acceleration = Statistic.new(base_acceleration)
	max_speed = Statistic.new(base_max_speed)
	max_life = Statistic.new(base_max_life)
	dmg = Statistic.new(base_dmg)
	dash_dmg_bonus = Statistic.new(base_dash_dmg_bonus)
	dash_duration = Statistic.new(base_dash_duration)
	nitro_up = Statistic.new(base_nitro_up)
	collect_radius = Statistic.new(base_collect_radius)
	#display_max_speed = Statistic.new(base_display_max_speed)
	drift_turn_bonus = Statistic.new(base_drift_turn_bonus)
	max_fuel = Statistic.new(base_max_fuel)


func get_car_stat(stat : Car_Stats) -> Statistic:
	match stat:
		Car_Stats.ACCELERATION: return acceleration
		Car_Stats.MAX_SPEED: return max_speed
		Car_Stats.MAX_LIFE: return max_life
		Car_Stats.DMG: return dmg
		Car_Stats.DASH_DMG_BONUS: return dash_dmg_bonus
		Car_Stats.DASH_DURATION: return dash_duration
		Car_Stats.NITRO_UP: return nitro_up
		Car_Stats.COLLECT_RADIUS: return collect_radius
		Car_Stats.DRIFT_TURN_BONUS: return drift_turn_bonus
		Car_Stats.MAX_FUEL: return max_fuel
	return null
	
func unscaled_speed()-> float:
	return max_speed.get_value() * StatsManager.max_speed / StatsManager.display_max_speed
