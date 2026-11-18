class_name StreamSpawnEntry
extends SpawnEntry
## Continuous spawn, started at half time (SpawnerAuto).

@export var enemy_type : EnemyManager.Enemy_Types
@export var is_infinite : bool = true
## true = spawns from the raid start, false = waits for a signal (half time...)
@export var auto_spawn : bool = false

@export_group("Progression")
## Seconds between two spawns (divided by the difficulty setting)
@export var spawn_rate_start : float = 1.0
@export var spawn_rate_end : float = 1.0
## Cap when is_infinite is false, scaled by the difficulty setting
@export var max_enemy_start : int = 10
@export var max_enemy_end : int = 10


func configure(spawner : Node, progress : float) -> void:
	var stream_spawner : StreamSpawner = spawner as StreamSpawner
	if stream_spawner == null:
		push_error("[StreamSpawnEntry] spawner_scene root is not a StreamSpawner")
		return
	stream_spawner.enemy_type = enemy_type
	stream_spawner.is_infinite = is_infinite
	stream_spawner.auto_spawn = auto_spawn
	stream_spawner.max_enemy_count = scaled_by_difficulty(lerp_int(max_enemy_start, max_enemy_end, progress))
	# Harder = shorter interval between two spawns
	stream_spawner.spawn_rate = lerpf(spawn_rate_start, spawn_rate_end, progress) / GameMaster.DIFFICULTIES_MOD[GameMaster.difficulty]
