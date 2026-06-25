class_name Spawner
extends Node2D

@export var scene_to_spawn : PackedScene
@export var cell_size : float = 32.0
@export var screen_margin : float = 0.0
@export var max_spawn_attempts : int = 20
@export var spawn_rate : float = 1

var free_cells : Array[Vector2i] = []
var camera : Camera2D


func _ready() -> void:
	camera = get_viewport().get_camera_2d()
	build_grid()
	setup_trigger()


# ---- KIDS HOOKS OVERDRIVABLE ----
func setup_trigger() -> void:
	pass

func get_spawn_parent() -> Node:
	return self

func on_spawned(_instance : Node) -> void: # AFTER ADD CHILD
	pass
	
func configure_instance(_instance : Node, _world_pos : Vector2) -> void: # BEFORE ADD CHILD
	pass

func build_grid() -> void:
	free_cells.clear()
	var wall_cells : Dictionary = {}
	var bounds : Rect2i
	var bounds_set : bool = false

	for wall in get_tree().get_nodes_in_group("walls"):
		if wall is TileMapLayer:
			var rect : Rect2i = wall.get_used_rect()
			bounds = rect if !bounds_set else bounds.merge(rect)
			bounds_set = true
			for cell : Vector2i in wall.get_used_cells():
				wall_cells[cell] = true

	if !bounds_set:
		push_warning("Spawner : aucun mur trouvé pour construire la grille")
		return

	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			if !wall_cells.has(cell):
				free_cells.append(cell)


func spawn() -> Node:
	if scene_to_spawn == null or free_cells.is_empty():
		return null

	for _i in range(max_spawn_attempts):
		var cell : Vector2i = free_cells.pick_random()
		var world_pos : Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size

		if is_on_screen(world_pos):
			continue

		var instance : Node = scene_to_spawn.instantiate()
		configure_instance(instance, world_pos)
		get_spawn_parent().add_child(instance)
		if instance is Node2D:
			instance.global_position = world_pos
		on_spawned(instance)
		return instance

	return null


func is_on_screen(world_pos : Vector2) -> bool:
	if camera == null:
		camera = get_viewport().get_camera_2d()
		if camera == null:
			return false
	var view_size : Vector2 = get_viewport_rect().size / camera.zoom
	var center : Vector2 = camera.get_screen_center_position()
	var view_rect := Rect2(center - view_size * 0.5, view_size).grow(screen_margin)
	return view_rect.has_point(world_pos)
	
