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
## Share of the car velocity given to the flying enemy, in world space.
## Negative = thrown backward (reads as a real hit), 0 = hop in place, > 0 = carried forward
@export_range(-1.5, 1.0) var air_forward_carry : float = -0.2
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

@export_group("HIT PAUSE (victim only)")
## The hit enemy freezes in white flash before being thrown. Local: the rest of the game runs
@export var victim_pause_enabled : bool = true
@export var victim_pause_duration : float = 0.05

@export_group("HIT STOP (global)")
## Whole game freeze, only on a strong hit after a calm moment (never inside a horde)
@export var hit_stop_enabled : bool = true
## Real seconds (not affected by the time scale)
@export var hit_stop_duration : float = 0.045
@export_range(0.0, 1.0) var hit_stop_time_scale : float = 0.05
## Car speed / max speed needed to trigger it
@export_range(0.0, 1.0) var hit_stop_min_speed_ratio : float = 0.6
## Seconds without any car hit required before: first hit of a horde yes, the next ones no
@export var hit_stop_isolation_time : float = 0.5
@export var hit_stop_cooldown : float = 1.0

@export_group("CAR KICK (sprite only)")
## Enemy hit: the car sprite snaps away from the enemy and yaws, then springs back.
## Driving physics untouched.
@export var car_kick_enabled : bool = true
## Recoil (px, car local space) at full speed
@export var car_kick_offset_px : float = 4.0
## Yaw (deg) at full speed for a pure side contact
@export var car_kick_yaw_deg : float = 4.0
## Intensity floor so that a slow bump still reads (intensity = car speed ratio)
@export_range(0.0, 1.0) var car_kick_min_intensity : float = 0.4
## Caps when several hits stack (horde)
@export var car_kick_max_offset_px : float = 7.0
@export var car_kick_max_yaw_deg : float = 7.0
## Return spring: higher stiffness = faster return, lower damping = more wobble
@export var car_kick_stiffness : float = 500.0
@export var car_kick_damping : float = 20.0

@export_group("CAR SLOWDOWN")
@export var car_slowdown_enabled : bool = true
## Speed share lost by the car per enemy hit
@export_range(0.0, 1.0) var car_speed_loss_per_hit : float = 0.03
## Cap of the speed share lost in a single physics frame, whatever the number of hits
@export_range(0.0, 1.0) var car_max_speed_loss_per_frame : float = 0.08
