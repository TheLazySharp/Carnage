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

@export_group("PERFECT DRIFT HIT")
## The rear of the car swipes an enemy while drifting and spinning fast: it becomes a projectile
## that bursts on the first enemy or wall it meets
@export var drift_hit_enabled : bool = true
## Car speed / max speed needed
@export_range(0.0, 1.0) var drift_hit_min_speed_ratio : float = 0.3
## Car rotation speed needed at the contact (deg/s): the tail must really swipe
@export var drift_hit_min_spin_deg : float = 220.0
## Projectile speed (px/s)
@export var drift_hit_throw_speed : float = 1000.0
## Knockback friction multiplier while flying (low = flies far)
@export_range(0.0, 1.0) var drift_hit_friction_ratio : float = 0.3
## Below this speed the projectile bursts on its own (out of steam)
@export var drift_hit_end_speed : float = 150.0
## Burst damages = car damages x this
@export var drift_hit_damage_multiplier : float = 3.0
## Enemies hurt by the burst, around the impact point (px)
@export var drift_hit_burst_radius : float = 40.0
@export var drift_hit_burst_knockback : float = 300.0
## Feedback on the hit
@export var drift_hit_stop_duration : float = 0.4
@export var drift_hit_shake : float = 10.0
## Shake on the hit itself (drift_hit_shake is the one of the burst)
@export var drift_hit_launch_shake : float = 20.0
## A perfect drift hit during a maneuver makes it count as amplified for the combo (like a dash)
@export var drift_hit_counts_for_combo : bool = true
## ...when it happened at most this many seconds before the maneuver ends
@export var drift_hit_combo_window : float = 1.5
## Camera on the hit: quick zoom in during the freeze, then back out while the enemy flies
## Extra zoom at the peak (0.35 = +35 %, 0 = off)
@export var drift_hit_zoom : float = 0.8
## Real seconds (the hit stop does not slow them down)
@export var drift_hit_zoom_in_time : float = 0.1
@export var drift_hit_zoom_out_time : float = 0.3
## Share of the way the view moves toward the impact point (0 = stays on the car)
@export_range(0.0, 1.0) var drift_hit_focus : float = 0.4
## Thrown enemy facing: true = back first (it looks at the car that hit it), false = face first
@export var drift_hit_face_backward : bool = true

## Particle scenes made by the graphic artist (null = no effect)
## Impact: blood shots (BloodShotPool) fanned along the tail swipe
@export var drift_hit_impact_vfx_enabled : bool = true
@export var drift_hit_blood_shots : int = 6
## Total fan angle of the shots (deg)
@export var drift_hit_blood_spread_deg : float = 40.0
## Trail: particles following the thrown enemy (Local Coords off, not one-shot)
@export var drift_hit_trail_enabled : bool = true
@export var drift_hit_trail_vfx : PackedScene

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

@export_group("CAR -> ENEMY FEEDBACK")
## Standard hit: shake scaled by the car speed
@export var car_hit_shake : float = 10.0
@export var car_hit_shake_time : float = 0.2
## Enemy thrown over the car: stronger shake
@export var air_throw_shake : float = 12.0
@export var air_throw_shake_time : float = 0.25
## Ploughing into a horde: one sound per type and one shake at most every N seconds (real time)
@export var car_hit_sfx_min_interval : float = 0.15
@export var car_hit_shake_min_interval : float = 0.1

@export_group("MANEUVER SUCCESS")
## Short freeze + camera zoom when a maneuver is performed
@export var maneuver_juice_enabled : bool = true
@export var maneuver_stop_duration : float = 0.0 #default = 0.25
## Extra zoom at the peak (0.15 = +15 %), real seconds for the timings
@export var maneuver_zoom : float = 0.0 #default = 0.4
@export var maneuver_zoom_in_time : float = 0.0 #default = 0.05
@export var maneuver_zoom_out_time : float = 0.0 #default = 0.3
## Maneuvers without this effect (e.g. the frequent short drift)
@export var maneuver_juice_excluded : Array[ManeuverManager.Type] = []
## Maneuver name: pops in big, then bounces back to its size (real time: plays during the freeze)
@export var maneuver_name_pop_scale : float = 2
@export var maneuver_name_pop_time : float = 0.
