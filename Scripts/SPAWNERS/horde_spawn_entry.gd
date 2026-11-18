class_name HordeSpawnEntry
extends SpawnEntry
## Idle hordes waiting on the map (HordeSpawner).

@export var enemy_type : EnemyManager.Enemy_Types
## true = hordes spawn with the map, false = they wait for trigger_signal
@export var auto_spawn : bool = true
## SignalManager signal that spawns the hordes when auto_spawn is false
## (launch_horde, coloss_incoming...)
@export var trigger_signal : StringName = &"launch_horde"
## Hordes chase the car as soon as they spawn (final horde...)
@export var chase_on_spawn : bool = false

@export_group("Progression")
@export var nb_horde_start : int = 6
@export var nb_horde_end : int = 6
## Enemies per horde, scaled by the difficulty setting
@export var horde_size_start : int = 20
@export var horde_size_end : int = 20

@export_group("Layout")
## Few big hordes need a wide disc, many small ones a tight one
@export var horde_radius_px : float = 128.0
@export var min_horde_spacing_px : float = 900.0


func configure(spawner : Node, progress : float) -> void:
	var horde_spawner : HordeSpawner = spawner as HordeSpawner
	if horde_spawner == null:
		push_error("[HordeSpawnEntry] spawner_scene root is not a HordeSpawner")
		return
	horde_spawner.enemy_type = enemy_type
	horde_spawner.nb_horde = lerp_int(nb_horde_start, nb_horde_end, progress)
	horde_spawner.max_enemy_count = scaled_by_difficulty(lerp_int(horde_size_start, horde_size_end, progress))
	horde_spawner.horde_radius_px = horde_radius_px
	horde_spawner.min_horde_spacing_px = min_horde_spacing_px
	horde_spawner.auto_spawn = auto_spawn
	horde_spawner.trigger_signal = trigger_signal
	horde_spawner.chase_on_spawn = chase_on_spawn
