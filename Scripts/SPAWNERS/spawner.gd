class_name Spawner
extends Node2D

@export var scene_to_spawn : PackedScene
@export var cell_size : float = 32.0
@export var screen_margin : float = 0.0
@export var max_spawn_attempts : int = 20
@export var spawn_rate : float = 1

@export var footprint : Vector2i = Vector2i(1, 1)
@export var occupy_cells : bool = false #if true, spawnable is considered as permanent (buildings, obstacles)

var last_footprint_cells : Array[Vector2i] = []
var free_cells : Array[Vector2i] = []
var free_cell_set : Dictionary = {}
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

func get_footprint() -> Vector2i:
	return footprint


func build_grid() -> void:
	free_cells.clear()
	free_cell_set.clear()
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
				free_cell_set[cell] = true

func spawn() -> Node:
	if scene_to_spawn == null or free_cells.is_empty():
		return null

	var size : Vector2i = get_footprint()

	for _i in range(max_spawn_attempts):
		var anchor : Vector2i = free_cells.pick_random()
		last_footprint_cells = get_footprint_cells(anchor, size)
		
		if !is_footprint_free(anchor, size):
			continue
		
		var world_center_pos : Vector2 = (Vector2(anchor) + Vector2(size) * 0.5) * cell_size
		
		if is_footprint_on_screen(anchor, size):
			continue

		var instance : Node = scene_to_spawn.instantiate()
		configure_instance(instance, world_center_pos)
		get_spawn_parent().add_child(instance)
		if instance is Node2D:
			instance.global_position = world_center_pos
		on_spawned(instance)

		if occupy_cells:
			occupy_footprint(anchor, size)
			
		return instance

	return null

#func is_on_screen(world_pos : Vector2) -> bool:
	#if camera == null:
		#camera = get_viewport().get_camera_2d()
		#if camera == null:
			#return false
	#var view_size : Vector2 = get_viewport_rect().size / camera.zoom
	#var center : Vector2 = camera.get_screen_center_position()
	#var view_rect := Rect2(center - view_size * 0.5, view_size).grow(screen_margin)
	#return view_rect.has_point(world_pos)
	


func is_footprint_free(anchor : Vector2i, size : Vector2i) -> bool:
	for size_width in range(size.y):
		for size_height in range(size.x):
			if !free_cell_set.has(anchor + Vector2i(size_height, size_width)):
				return false
	return true
 

func occupy_footprint(anchor : Vector2i, size : Vector2i) -> void:
	for size_width in range(size.y):
		for size_height in range(size.x):
			var cell : Vector2i = anchor + Vector2i(size_height, size_width)
			free_cell_set.erase(cell)
			free_cells.erase(cell)

func is_footprint_on_screen(anchor : Vector2i, size : Vector2i) -> bool:
	if camera == null:
		camera = get_viewport().get_camera_2d()
		if camera == null:
			return false
	var view_size : Vector2 = get_viewport_rect().size / camera.zoom
	var center : Vector2 = camera.get_screen_center_position()
	var view_rect := Rect2(center - view_size * 0.5, view_size).grow(screen_margin)
	var block_rect := Rect2(Vector2(anchor) * cell_size, Vector2(size) * cell_size)
	return view_rect.intersects(block_rect)
	
func get_footprint_cells(anchor : Vector2i, size : Vector2i) -> Array[Vector2i]:
	var cells : Array[Vector2i] = []
	for dy in range(size.y):
		for dx in range(size.x):
			cells.append(anchor + Vector2i(dx, dy))
	return cells
