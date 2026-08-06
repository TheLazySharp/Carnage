class_name BloodImpactPool
extends Node2D

# RING BUFFER

@export_group("SCENE")
@export var blood_scene : PackedScene
@export var pool_size: int = 200
var blood_roots: Array[Node2D] = []
var blood_splatters: Array[BloodSplatter] = []
var write_cursor: int = 0

@export_group("FRESHNESS")
@export var freshness_duration: float = 10.0
@export var harvest_radius: float = 40.0

var spawn_times: PackedFloat32Array
var splat_positions: PackedVector2Array
var fresh_indices: Array[int] = []

func _ready() -> void:
	SignalManager.next_day.connect(clear_all)
	blood_roots.resize(pool_size)
	blood_splatters.resize(pool_size)
	for i: int in range(pool_size):
		var root: Node2D = blood_scene.instantiate()
		add_child(root)
		root.hide()
		blood_roots[i] = root
		blood_splatters[i] = root.get_node("BloodSplatter") as BloodSplatter
	spawn_times.resize(pool_size)
	splat_positions.resize(pool_size)

func _process(_delta: float) -> void:
	if fresh_indices.is_empty():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	for k: int in range(fresh_indices.size() - 1, -1, -1):
		var idx: int = fresh_indices[k]
		var age: float = now - spawn_times[idx]
		if age >= freshness_duration:
			blood_splatters[idx].set_rotten()
			fresh_indices.remove_at(k)
			continue
		blood_splatters[idx].set_freshness(age / freshness_duration)


func splat_blood(blood_position: Vector2, blood_rotation: float) -> void:
	var idx: int = write_cursor
	write_cursor = (write_cursor + 1) % pool_size
	
	fresh_indices.erase(idx)
	
	var root: Node2D = blood_roots[idx]
	root.global_position = blood_position
	root.rotation = blood_rotation
	root.show()
	
	spawn_times[idx] = Time.get_ticks_msec() / 1000.0
	splat_positions[idx] = blood_position
	blood_splatters[idx].set_freshness(0.0)
	fresh_indices.append(idx)
	
	blood_splatters[idx].play()
	
func harvest(harvest_position: Vector2) -> int:
	var harvested: int = 0
	var radius_squared: float = harvest_radius * harvest_radius
	for k: int in range(fresh_indices.size() - 1, -1, -1):
		var idx: int = fresh_indices[k]
		if splat_positions[idx].distance_squared_to(harvest_position) <= radius_squared:
			blood_splatters[idx].set_rotten()
			fresh_indices.remove_at(k)
			harvested += 1
	return harvested


func clear_all() -> void:
	for root: Node2D in blood_roots:
		root.hide()
	for splatter: BloodSplatter in blood_splatters:
		splatter.clear_splats()
	fresh_indices.clear()
	write_cursor = 0
