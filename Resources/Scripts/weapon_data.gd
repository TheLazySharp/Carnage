extends Resource

class_name WeaponData

enum Stats_Types {
	N_A,
	DMG,
	FIRE_RATE,
	NB_AMMO,
	RANGE,
	RADIUS,
	COOL_DOWN,
	SPEED,
	SPEED_ROTATION,
	NB_PROJECTILE
}


enum Type {
	SHORT_RANGE,
	LONG_RANGE,
	EXPLOSIVE,
	SINGLE_SHOT,
	BURST_SHOT,
	ELEMENTAL,
	N_A
}

@export_group("GLOBAL INFO")
@export var weapon_ref : ShopManager.CONST_REFS
@export var weapon_name : String
@export var weapon_icon: Texture2D
@export var weapon_is_active := true
@export var max_level : int
@export var description : String
@export var type_1 : Type
@export var type_2 : Type
@export var tar_up_stat : Stats_Types

@export_group("UID AND SCENES")
@export var weapon_scene_uid : String
@export var weapon_ammo_scene : PackedScene
@export var weapon_ammo_res : WeaponData
@export var weapon_sfx: AudioStreamRandomizer
## Death animation played when this weapon lands the killing blow.
## Falls back to DEFAULT if the enemy has no death state of this type.
@export var death_type : EnemyManager.DEATH_TYPES = EnemyManager.DEATH_TYPES.DEFAULT

@export_group("BASE STATS")
@export var base_dmg : = 5
@export var base_atk_range : float
@export var base_radius := 100
@export var base_speed_rotation:= 15
@export var base_fire_rate: float
@export var base_cool_down: float
@export var base_nb_ammo: int = 1
@export var max_projectile: int = 10
@export var base_nb_projectile: int = 1
@export var base_speed : float

@export_group("MANEUVERS")
## Preferred maneuvers: tried first when the weapon is placed automatically (until the build screen exists)
@export var assigned_maneuvers : Array[ManeuverManager.Type] = []
## Stat that sets the base projectile count of a maneuver salvo
@export var salvo_base_stat : Stats_Types = Stats_Types.NB_AMMO
## Bullets fired in each direction of a salvo (stream). N_A = one bullet per direction, sweeping the arc
@export var stream_stat : Stats_Types = Stats_Types.N_A
## Extra projectiles per drift level
@export var drift_level_bonus : float = 0.5
## Projectile count multiplier when the maneuver is dashed
@export var amplified_multiplier : float = 2.5
## How much the maneuver arc raises the count: 0 = the shape only spreads the projectiles,
## 1 = one base count per quarter circle covered
@export_range(0.0, 1.0) var arc_scaling : float = 0.0
## Share of the combo multiplier applied to the projectile count (1 = full combo)
@export var combo_projectile_share : float = 1.0
## Share of the combo multiplier applied to the damage (0.25: a x5 combo deals x2 damage)
@export var combo_damage_share : float = 0.25

@export_group("OTHERS")
@export var dmg_on_resources := 1
@export var healing_power: int

#all stats_UPGRADE are use to display stats difference if the weapon is upgrade on player level up. Only for UI purpose

var current_level: int = 0
var dmg_upgrade : int
var fire_rate_upgrade : float
var cool_down_upgrade : float
var radius_upgrade : float
var nb_ammo_upgrade : int

var total_damages_dealt : int = 0
var equipped_sessions : Array[float] = []
var total_equipped_time : float = 0

var is_equiped: = false
var crafted : bool = false
var bonus : bool = false

# ------- STATS THAT CAN BE MODIFIED -----------
var dmg : Statistic 
var fire_rate : Statistic
var cool_down : Statistic
var radius : Statistic
var nb_ammo : Statistic
var atk_range : Statistic
var speed_rotation : Statistic
var speed : Statistic
var nb_projectile : Statistic
var stats : Dictionary[Stats_Types,Statistic] = {}


# ---------------- if we want to display the preview value : level_preview = 1 (0 otherwise / for actual level up)
func dmg_formula(level_preview : int) -> float : 
	var stat_bonus : int = current_level if tar_up_stat == Stats_Types.DMG else 0
	return roundi(base_dmg + ((stat_bonus + level_preview) * 0.1 * 28))

func fire_rate_formula(level_preview : int) -> float : 
	var stat_bonus : int = current_level if tar_up_stat == Stats_Types.FIRE_RATE else 0
	return (base_fire_rate - (stat_bonus + level_preview) * 0.02)

func cool_down_formula(level_preview : int) -> float : 
	var stat_bonus : int = current_level if tar_up_stat == Stats_Types.COOL_DOWN else 0
	return (base_cool_down + (stat_bonus + level_preview) * 0.1)

func radius_formula(_level_preview : int) -> float : 
	#var stat_bonus : int = current_level if tar_up_stat == Stats_Types.DMG else 0
	return (base_radius)

func nb_ammo_formula(level_preview : int) -> float : 
	var stat_bonus : int = current_level if tar_up_stat == Stats_Types.NB_AMMO else 0
	return roundi(base_nb_ammo + (stat_bonus + level_preview))

func atk_range_formula(_level_preview : int) -> float : 
	#var stat_bonus : int = current_level if tar_up_stat == Stats_Types.DMG else 0
	return (base_atk_range)

func speed_rotation_formula(_level_preview : int) -> float : 
	#var stat_bonus : int = current_level if tar_up_stat == Stats_Types.DMG else 0
	return (base_speed_rotation)

func speed_formula(_level_preview : int) -> float : 
	#var stat_bonus : int = current_level if tar_up_stat == Stats_Types.DMG else 0
	return (base_speed)

func nb_projectile_formula(level_preview : int) -> float : 
	var stat_bonus : int = current_level if tar_up_stat == Stats_Types.NB_PROJECTILE else 0
	return roundi(base_nb_projectile + (stat_bonus + level_preview))

## Projectile count for a maneuver salvo: base stat raised by the combo (main ramp),
## the maneuver arc and power, the driving quality, the drift level and the dash
func get_salvo_count(maneuver_type : ManeuverManager.Type, intensity : float, drift_level : int, is_amplified : bool, combo_multiplier : float) -> int :
	var quarters : float = maxf(ManeuverManager.get_pattern(maneuver_type).y / (PI * 0.5), 1.0)
	var count : float = get_weapon_stat(salvo_base_stat).get_value() * (1.0 + (quarters - 1.0) * arc_scaling)
	count *= ManeuverManager.get_power(maneuver_type)
	count *= 0.5 + 0.5 * intensity
	count *= 1.0 + drift_level * drift_level_bonus
	count *= 1.0 + (combo_multiplier - 1.0) * combo_projectile_share
	if is_amplified:
		count *= amplified_multiplier
	# Rounded up (minus a float margin): every bonus adds at least one projectile, even on a small base
	return maxi(ceili(count - 0.001), 1)


## Damage multiplier from the combo: a share only, the combo mostly raises the projectile count
func get_combo_damage_multiplier(combo_multiplier : float) -> float :
	return 1.0 + (combo_multiplier - 1.0) * combo_damage_share

func get_shots_per_direction() -> int :
	if stream_stat == Stats_Types.N_A:
		return 1
	return maxi(roundi(get_weapon_stat(stream_stat).get_value()), 1)

func init_stats() -> void : 
	dmg = Statistic.new(dmg_formula(0))
	fire_rate = Statistic.new(fire_rate_formula(0))
	cool_down = Statistic.new(cool_down_formula(0))
	radius = Statistic.new(radius_formula(0))
	nb_ammo = Statistic.new(nb_ammo_formula(0))
	atk_range = Statistic.new(atk_range_formula(0))
	speed_rotation = Statistic.new(speed_rotation_formula(0))
	speed = Statistic.new(speed_formula(0))
	nb_projectile = Statistic.new(nb_projectile_formula(0))
	
	
	stats = {
		Stats_Types.DMG : dmg,
		Stats_Types.FIRE_RATE: fire_rate,
		Stats_Types.NB_AMMO : nb_ammo,
		Stats_Types.RANGE : atk_range,
		Stats_Types.RADIUS : radius,
		Stats_Types.COOL_DOWN : cool_down,
		Stats_Types.SPEED : speed,
		Stats_Types.SPEED_ROTATION : speed_rotation,
		Stats_Types.NB_PROJECTILE : nb_projectile
	}

	SignalManager.emit_signal("weapon_stats_initiated",self)


func get_target_upgrade_stat() -> Statistic :
	match self.tar_up_stat:
		Stats_Types.DMG : return dmg
		Stats_Types.FIRE_RATE : return fire_rate
		Stats_Types.NB_AMMO : return nb_ammo
		Stats_Types.RANGE : return atk_range
		Stats_Types.RADIUS : return radius
		Stats_Types.COOL_DOWN : return cool_down
		Stats_Types.SPEED : return speed
		Stats_Types.SPEED_ROTATION : return speed_rotation
		Stats_Types.NB_PROJECTILE : return nb_projectile
	return null
	
func get_target_stat_new_value(level_preview : int) -> float :
	match self.tar_up_stat:
		Stats_Types.DMG : return dmg_formula(level_preview)
		Stats_Types.FIRE_RATE : return fire_rate_formula(level_preview)
		Stats_Types.NB_AMMO : return nb_ammo_formula(level_preview)
		Stats_Types.RANGE : return atk_range_formula(level_preview)
		Stats_Types.RADIUS : return radius_formula(level_preview)
		Stats_Types.COOL_DOWN : return cool_down_formula(level_preview)
		Stats_Types.SPEED : return speed_formula(level_preview)
		Stats_Types.SPEED_ROTATION : return speed_rotation_formula(level_preview)
		Stats_Types.NB_PROJECTILE : return nb_projectile_formula(level_preview)
	return 0

func get_weapon_stat(stat : Stats_Types) -> Statistic :
	match stat:
		Stats_Types.DMG : return dmg
		Stats_Types.FIRE_RATE : return fire_rate
		Stats_Types.NB_AMMO : return nb_ammo
		Stats_Types.RANGE : return atk_range
		Stats_Types.RADIUS : return radius
		Stats_Types.COOL_DOWN : return cool_down
		Stats_Types.SPEED : return speed
		Stats_Types.SPEED_ROTATION : return speed_rotation
		Stats_Types.NB_PROJECTILE : return nb_projectile
	return null


func level_up() -> void : 
	current_level += 1
	var target_upgraded_stat : Statistic = get_target_upgrade_stat()
	target_upgraded_stat.base_value = get_target_stat_new_value(0)
	target_upgraded_stat.dirty = true
	target_upgraded_stat.recalculate()
	
func get_active_duration() -> float:
	var total : float = 0
	for i in equipped_sessions:
		total += TimeManager.active_time - i
	return total
	
