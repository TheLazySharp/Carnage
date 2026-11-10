extends Resource
class_name ScoreSettings

@export_group("KILLS")
@export var kill_points : Dictionary[EnemyManager.Enemy_Types, int] = {}

@export_group("DRIVING")
@export var distance_unit : float = 1000.0
@export var distance_points : int = 10
@export var maneuver_points : int = 2
@export var amplified_maneuver_points : int = 2
@export var perfect_hit_points : int = 3

@export_group("HORDES")
@export var horde_points : int = 10

@export_group("PENALTIES")
@export var damage_taken_points : float = 0.5

@export_group("MULTIPLIERS")
## Total x (1 + (max combo - 1) x share): 0.25 -> a x5 combo doubles the score
@export var combo_total_share : float = 0.25
