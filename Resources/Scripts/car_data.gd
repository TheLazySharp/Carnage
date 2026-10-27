extends Resource
class_name CarData

@export var car_name : String
@export var seats : int = 5
@export_group("MANEUVERS")
## Maneuvers the car owns at the start of a run (the others are bought at the shop)
@export var base_maneuvers : Array[ManeuverManager.Type] = []
## How many maneuvers one weapon can be placed on
@export var maneuvers_per_weapon : int = 2
## Car ultimate, triggered by closing a loop (scene with a trigger(polygon, damage_multiplier) method)
@export var ultimate_scene : PackedScene

## Base time (seconds) to recharge the ultimate at combo x1
@export var base_ultimate_recharge_time : float = 20.0

@export_group("COMBO")
@export var base_combo_window : float = 4.0   # seconds to chain the next maneuver
@export var base_combo_step : float = 0.25     # multiplier gained per new maneuver
@export var base_combo_decay : float = 0.2    # multiplier lost per second once the window is over
@export var base_combo_max : float = 5.0


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
@export var base_max_nitro := 100


@export_group("DRIVING")
@export var friction := 500.0
@export var turn_speed := 3.2
@export var velocity_floor: float = 50
@export var burnout_boost : float = 200
@export var dash_fuel_down : int = 10
@export var regular_fuel_leak : int = 1


@export_group("DRIFT")
@export var drift_grip := 0.015
@export var normal_grip := 0.18
@export var max_drift_damping := 3.5
@export var min_drift_speed := 150.0
@export var snap_grip := 0.75
@export var snap_speed := 8.0
@export var charge_colors : Array[Color] = [
	Color(1.766, 2.17, 3.0, 0.902),   # tier 0 
	Color(0.437, 1.123, 3.0, 0.902),  # tier 1
	Color(0.157, 1.167, 4.395, 0.902),   # tier 2
]

@export_group("SKIDS")
@export var skid_spacing := 8.0
@export var skid_lifetime := 2.5
@export var skid_fade_speed := 1.5

@export_group("AUDIO")
@export var start_engine_Sound: AudioStreamMP3

@export_group("VFX")
@export var car_sprite: Texture2D
#@export var car_explosion: SpriteFrames

var drifting : bool = false
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
	MAX_FUEL,
	MAX_NITRO,
	COMBO_WINDOW,
	COMBO_STEP,
	COMBO_DECAY,
	COMBO_MAX,
	ULTIMATE_RECHARGE_SPEED,
	DRIFT_CHARGE_SPEED,
	DRIFT_HIT_POWER
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
	BUMPER,
	REAR_BUMPER
}

var acceleration: Statistic
var max_speed: Statistic
var max_life: Statistic

var dmg: Statistic
var dash_dmg_bonus : Statistic #dmg during dash
var dash_duration : Statistic #dash duration
var nitro_up : Statistic #nitro gauge fill up speed
var collect_radius : Statistic
var drift_turn_bonus : Statistic
var max_fuel : Statistic
var max_nitro : Statistic

var combo_window : Statistic
var combo_step : Statistic
var combo_decay : Statistic              # lower is better
var combo_max : Statistic
var ultimate_recharge_speed : Statistic  # multiplier on the recharge speed
var drift_charge_speed : Statistic       # multiplier on the drift charge speed
var drift_hit_power : Statistic          # multiplier on the perfect drift hit burst damages (rear bumper)

## Level of each car part for this run (0 = not upgraded)
var part_levels : Dictionary[Car_Upgrades, int] = {}

var stat_modifiers : Array[Modifier] = []
@warning_ignore("unused_signal")
signal stat_adjusted(stat : Statistic )

var current_life : int 
var current_fuel : int 
var current_nitro : int


#--- Charms -----
var invincible : bool = false
var combo_repeat_gain : float = 0.0
var free_amplify_chance : float = 0.0  #dice charm
var salvo_repeat_chance : float = 0.0  #rabbit foot charm
var wall_keeps_drift : bool = false  #hammer charm

var is_unlocked : bool = false

func init_stats() -> void:
	if CarManager.unlocked_cars.has(self):
		is_unlocked = true
	
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
	drift_turn_bonus = Statistic.new(base_drift_turn_bonus)
	max_fuel = Statistic.new(base_max_fuel)
	max_nitro = Statistic.new(base_max_nitro)
	combo_window = Statistic.new(base_combo_window)
	combo_step = Statistic.new(base_combo_step)
	combo_decay = Statistic.new(base_combo_decay)
	combo_max = Statistic.new(base_combo_max)
	ultimate_recharge_speed = Statistic.new(1.0)
	drift_charge_speed = Statistic.new(1.0)
	drift_hit_power = Statistic.new(1.0)
	
	invincible = false
	combo_repeat_gain = 0.0
	free_amplify_chance = 0.0
	salvo_repeat_chance = 0.0
	wall_keeps_drift = false
	
	part_levels.clear()


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
		Car_Stats.MAX_NITRO: return max_nitro
		Car_Stats.COMBO_WINDOW: return combo_window
		Car_Stats.COMBO_STEP: return combo_step
		Car_Stats.COMBO_DECAY: return combo_decay
		Car_Stats.COMBO_MAX: return combo_max
		Car_Stats.ULTIMATE_RECHARGE_SPEED: return ultimate_recharge_speed
		Car_Stats.DRIFT_CHARGE_SPEED: return drift_charge_speed
		Car_Stats.DRIFT_HIT_POWER: return drift_hit_power
	return null
	
func unscaled_speed()-> float:
	return max_speed.get_value() * StatsManager.max_speed / StatsManager.display_max_speed

func get_part_level(part : Car_Upgrades) -> int:
	return part_levels.get(part, 0)

## One more level on a car part: its modifier on each of its target stats. False when maxed
func upgrade_part(part_boost : BoostData) -> bool:
	if !part_boost.is_car_part():
		return false
	var level : int = get_part_level(part_boost.car_part)
	if level >= part_boost.get_max_level():
		return false
	for target_stat : BoostData.Target_Stats in part_boost.target_stats:
		var stat : Statistic = part_boost.get_car_stat(target_stat, self)
		if stat != null:
			stat.add_modifier(part_boost.make_part_modifier(level))
	part_levels[part_boost.car_part] = level + 1
	return true
