extends Resource
class_name JuiceSettings
## Single place for every feel / juice tuning. One .tres, edited in the inspector.
## Scripts read it through: const JUICE : JuiceSettings = preload("res://juice/juice_settings.tres")

@export_group("CAR -> ENEMY IMPACT")
@export var enemy_impact_enabled : bool = true
## Half-angle (deg) of the frontal cone around the car's motion axis.
## Inside: enemy flung ahead. Outside: enemy flung sideways.
@export_range(0.0, 90.0) var frontal_cone_deg : float = 35.0
## Share of the car speed given to a frontal throw (> 1 = the enemy outruns the car)
@export var frontal_speed_transfer : float = 1.4
## Random deviation (deg) of a frontal throw toward the enemy's side: clears the car's path
@export var frontal_deflect_min_deg : float = 10.0
@export var frontal_deflect_max_deg : float = 35.0
## Share of the car speed given to a side throw
@export var side_speed_transfer : float = 1.0
## Forward component added to a side throw (0 = pure perpendicular ejection)
@export var side_forward_carry : float = 0.5
## Throw speed floor (px/s) so that a slow bump still reads
@export var min_throw_speed : float = 80.0
## Enemy impact_force / this value = per-type weight multiplier (300 = EnemyData default)
@export var impact_force_reference : float = 300.0

@export_group("CAR -> ENEMY AIR THROW")
## Fake flight in top-down: the enemy grows then shrinks (scale arc) and spins
@export var air_throw_enabled : bool = true
## Car speed / max speed needed for a frontal hit to send the enemy over the car
@export_range(0.0, 1.0) var air_min_speed_ratio : float = 0.5
## Share of the car velocity kept by the enemy (< 1: the car passes under it, it lands behind)
@export_range(0.0, 1.0) var air_forward_carry : float = 0.3
## Random spread of the flight direction (deg)
@export var air_spread_deg : float = 15.0
## Flight time (s) at air_min_speed_ratio / at full speed
@export var air_duration_min : float = 0.35
@export var air_duration_max : float = 0.6
## Scale added at the top of the arc (0.8 = x1.8)
@export var air_scale_peak : float = 0.8
## Spin during the flight, in turns (random in range, random direction)
@export var air_spin_turns_min : float = 0.5
@export var air_spin_turns_max : float = 1.25
## Knockback friction multiplier while flying (0 = no drag in the air)
@export_range(0.0, 1.0) var air_friction_ratio : float = 0.0
## Speed share kept when touching the ground (slide after landing)
@export_range(0.0, 1.0) var air_landing_speed_keep : float = 0.5

@export_group("CAR SLOWDOWN")
@export var car_slowdown_enabled : bool = true
## Speed share lost by the car per enemy hit
@export_range(0.0, 1.0) var car_speed_loss_per_hit : float = 0.03
## Cap of the speed share lost in a single physics frame, whatever the number of hits
@export_range(0.0, 1.0) var car_max_speed_loss_per_frame : float = 0.08
