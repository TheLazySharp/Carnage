class_name SpawnEntry
extends Resource
## One spawner of a raid: which scene, when it is active, how it is tuned.
## Subclasses only hold balancing values and apply them in configure().
## Technical settings (timers, sounds, entry distance...) stay in the scene.

## Spawner scene instanced by the RaidSpawnDirector
@export var spawner_scene : PackedScene
@export var enabled : bool = true
## Roadmap rows where this entry is active (-1 = no limit)
@export var min_row : int = -1
@export var max_row : int = -1
## District types concerned. Empty = every raid district
@export var district_types : Array[DistrictsData.types] = []


func is_active_for(row : int, district_type : DistrictsData.types) -> bool:
	if not enabled or spawner_scene == null:
		return false
	if min_row != -1 and row < min_row:
		return false
	if max_row != -1 and row > max_row:
		return false
	return district_types.is_empty() or district_types.has(district_type)


## Called BEFORE add_child: the spawner's _ready() already sees these values
func configure(_spawner : Node, _progress : float) -> void:
	pass


# ---------------- BALANCING HELPERS ----------------
func lerp_int(start_value : int, end_value : int, progress : float) -> int:
	return roundi(lerpf(float(start_value), float(end_value), progress))


## Enemy counts only: the difficulty setting scales them on top of the table
func scaled_by_difficulty(value : int) -> int:
	return maxi(roundi(float(value) * GameMaster.DIFFICULTIES_MOD[GameMaster.difficulty]), 0)
