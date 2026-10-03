class_name BloodImpactPool
extends Node2D

# RING BUFFER

@export_group("SCENE")
@export var blood_scene : PackedScene
@export var pool_size: int = 1000
var blood_roots: Array[Node2D] = []
var blood_splatters: Array[BloodSplatter] = []
var write_cursor: int = 0

@export_group("FRESHNESS")
@export var harvest_radius: float = 40.0
# Visual freshness applied when a puddle becomes collectible (0 = fresh look, 1 = almost rotten)
@export var ripe_freshness: float = 0.5

var splat_positions: PackedVector2Array
# Deposited during the current lap: not collectible yet
var pending_indices: Array[int] = []
# Deposited during the previous lap: collectible until the next lap completes
var ripe_indices: Array[int] = []

func _ready() -> void:
	SignalManager.next_day.connect(clear_all)
	SignalManager.lap_completed.connect(_on_lap_completed)
	blood_roots.resize(pool_size)
	blood_splatters.resize(pool_size)
	for i: int in range(pool_size):
		var root: Node2D = blood_scene.instantiate()
		add_child(root)
		root.hide()
		blood_roots[i] = root
		blood_splatters[i] = root.get_node("BloodMask") as BloodSplatter
	splat_positions.resize(pool_size)




func splat_blood(blood_position: Vector2, blood_rotation: float) -> void:
	var idx: int = write_cursor
	write_cursor = (write_cursor + 1) % pool_size
	
	# The ring buffer may recycle a puddle that is still pending or ripe
	pending_indices.erase(idx)
	ripe_indices.erase(idx)
	
	var root: Node2D = blood_roots[idx]
	root.global_position = blood_position
	root.rotation = blood_rotation
	root.show()
	
	splat_positions[idx] = blood_position
	blood_splatters[idx].set_freshness(0.0)
	pending_indices.append(idx)
	
	blood_splatters[idx].splat_blood()
	# Shared emitters (Vfx autoload): the old particles flew along the root's local -X axis
	Vfx.blood_impact(blood_position, -Vector2.from_angle(blood_rotation))
	
func harvest(harvest_position: Vector2) -> int:
	# Only blood deposited during the previous lap can be absorbed
	if ripe_indices.is_empty():
		return 0
	var harvested: int = 0
	var radius_squared: float = harvest_radius * harvest_radius
	for k: int in range(ripe_indices.size() - 1, -1, -1):
		var idx: int = ripe_indices[k]
		if splat_positions[idx].distance_squared_to(harvest_position) <= radius_squared:
			blood_splatters[idx].vacuum()
			ripe_indices.remove_at(k)
			harvested += 1
	return harvested


func clear_all() -> void:
	for root: Node2D in blood_roots:
		root.hide()
	for splatter: BloodSplatter in blood_splatters:
		splatter.clear_splats()
	pending_indices.clear()
	ripe_indices.clear()
	write_cursor = 0
	

func _on_lap_completed(_lap_count: int) -> void:
	# Blood from two laps ago coagulates and can no longer be absorbed
	for idx: int in ripe_indices:
		blood_splatters[idx].set_rotten()
	# Blood from the lap that just ended becomes collectible (swap arrays to avoid allocation)
	var previous_ripe: Array[int] = ripe_indices
	ripe_indices = pending_indices
	pending_indices = previous_ripe
	pending_indices.clear()
	for idx: int in ripe_indices:
		blood_splatters[idx].set_freshness(ripe_freshness)
