extends Spawner

var building : BuildingData
var has_spawned : bool = false
var flow_ready : bool = false
var grid_ready : bool = false

@onready var flow_field_manager: FlowFieldManager = $"/root/World/FlowFieldManager"
@onready var hordes_manager: HordeManager = $"/root/World/HordesManager"


func setup_trigger() -> void:
	flow_field_manager.walls_scanned.connect(_on_flow_ready)
	hordes_manager.wall_grid_ready.connect(_on_grid_ready)
	


func configure_instance(instance : Node, _world_pos : Vector2) -> void:
	if instance is Building:
		instance.building_data = building
	

func _on_flow_ready() -> void:
	flow_ready = true
	try_spawn()

func _on_grid_ready() -> void : 
	grid_ready = true
	try_spawn()

func try_spawn() -> void:
	if has_spawned or !flow_ready or !grid_ready:
		return
	has_spawned = true
	building = BuildingsManager.pick_building(GameMaster.current_biome, RoadMapManager.last_district.type)
	if building == null:
		push_warning("BuildingSpawner : aucun building à spawn")
		return
	scene_to_spawn = building.building_scene
	footprint = building.footprint_32
	spawn()


func on_spawned(instance : Node) -> void:
	(instance as Node2D).global_position = Vector2(last_footprint_cells[0]) * cell_size
	flow_field_manager.add_obstacles(last_footprint_cells)
	print("building aligné sur : ", (instance as Node2D).global_position)
	
func is_placement_valid(_anchor : Vector2i, size : Vector2i, world_center : Vector2) -> bool:
	if building == null:
		return true
	var radius : float = GeoTools.interaction_radius(size, cell_size, building.circle_margin)
	return GeoTools.is_circle_in_rect(world_center, radius, map_rect_px())
