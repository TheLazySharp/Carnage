##grid_controller.gd
#extends Node3D
#
#@export var grid_size: Vector2i = Vector2i(50, 50)
#@export var cell_radius: float = 1.0
#@export var player: Node3D
#@export var update_interval := 0.1
#@export var movement_threshold := 0.5
#@export var full_rebuild_interval := 20.0
#var rebuild_timer := 0.0
#
#var flow_field: FlowField
#var last_player_pos: Vector3
#var thread := Thread.new()
#var is_thread_running := false
#var is_flow_ready := false
#var thread_result: FlowField
#var update_timer := 0.0
#
#func _ready():
	#flow_field = FlowField.new(cell_radius, grid_size)
	#flow_field.create_grid()
	#flow_field.create_cost_field(_terrain_cost_query)
#
	#last_player_pos = player.global_position
	#var start_cell = flow_field.get_cell_from_world_pos(last_player_pos)
	#flow_field.create_integration_field(start_cell)
	#flow_field.create_flow_field(player.global_position)
#
#func _process(delta):
	#update_timer += delta
	#rebuild_timer += delta
#
	#var cur_pos = player.global_position
	#var dist_sq = cur_pos.distance_squared_to(last_player_pos)
	#if update_timer >= update_interval:
		#update_timer = 0.0
		#var should_force_update := false
		#if dist_sq > movement_threshold * movement_threshold:
			#should_force_update = true
		#if rebuild_timer >= full_rebuild_interval:
			#rebuild_timer = 0.0
			#should_force_update = true
		#if should_force_update:
			#last_player_pos = cur_pos
			#var cur_cell = flow_field.get_cell_from_world_pos(cur_pos)
			#if cur_cell:
				#start_flow_thread(cur_cell)
#
	#if is_flow_ready:
		#if is_thread_running:
			#thread.wait_to_finish()
			#is_thread_running = false
		#is_flow_ready = false
		#for x in grid_size.x:
			#for y in grid_size.y:
				#var cell = flow_field.grid[x][y]
				#var new_cell = thread_result.grid[x][y]
				#cell.best_cost = new_cell.best_cost
				#cell.best_direction = new_cell.best_direction
#
#func start_flow_thread(dest_cell: Cell):
	#if is_thread_running:
		#return
	#is_thread_running = true
	#var player_pos = player.global_position
	#thread.start(Callable(self, "_thread_build_flow").bind(dest_cell, player_pos))
#
#func _thread_build_flow(dest_cell: Cell, player_pos: Vector3):
	#var temp_flow = FlowField.new(cell_radius, grid_size)
	#temp_flow.create_grid()
#
	#for x in grid_size.x:
		#for y in grid_size.y:
			#var source = flow_field.grid[x][y]
			#var target = temp_flow.grid[x][y]
			#target.cost = source.cost
#
	#for column in temp_flow.grid:
		#for cell in column:
			#cell.best_cost = 65535
			#cell.best_direction = GridDirection.NONE
#
	#var dest_copy = temp_flow.get_cell(dest_cell.grid_index.x, dest_cell.grid_index.y)
	#temp_flow.create_integration_field(dest_copy)
	#temp_flow.create_flow_field(player_pos)
	#thread_result = temp_flow
	#is_flow_ready = true
#
#func _terrain_cost_query(world_pos: Vector3) -> int:
	#var space = get_world_3d().direct_space_state
	#var shape := BoxShape3D.new()
	#shape.size = Vector3.ONE * cell_radius
	#var params := PhysicsShapeQueryParameters3D.new()
	#params.shape = shape
	#params.transform = Transform3D(Basis(), world_pos)
	#params.collision_mask = 0b11
#
	#var results := space.intersect_shape(params, 1)
	#for hit in results:
		#if hit.collider and hit.collider is Node3D:
			#var col_layer = hit.collider.collision_layer
			#if col_layer & (1 << 0):
				#return 255
			#elif col_layer & (1 << 1):
				#return 3
	#return 0
