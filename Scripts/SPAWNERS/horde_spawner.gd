extends Spawner
class_name HordeSpawner
## Spawns nb_horde idle hordes at random, spaced positions on the generated map.
## Placement goes entirely through the Spawner base: build_grid() fills
## free_cells from MapData, spawn() picks a cell, and is_placement_valid()
## restricts it to the disc of the horde currently being built.

const ENEMY = preload("uid://c31g0smlywes2")

@export var is_active : bool = true
@export var enemy_type : EnemyManager.Enemy_Types
@export var nb_horde : int = 6
@export var max_enemy_count : int
@export var min_horde_spacing_px : float = 900.0
@export var min_distance_from_entry_px : float = 1200.0
@export var horde_radius_px : float = 128.0
@export var use_map_seed : bool = true
## true = hordes spawn with the map, false = they wait for trigger_signal
@export var auto_spawn : bool = true
## SignalManager signal that spawns the hordes when auto_spawn is false
@export var trigger_signal : StringName = &"launch_horde"
## Hordes chase the car as soon as they spawn instead of waiting idle
@export var chase_on_spawn : bool = false
## Hordes instantiated with the map and kept dormant (no process, physics or rendering) until trigger_signal,
## then woken one per frame away from the car. Needs auto_spawn = false
@export var prespawn_dormant : bool = false
## Final hordes appear in the map edge band: free cells closer than this to the map border.
## Covers the building belt + sidewalk + outer street (generator margin = 11 cells)
@export var periphery_depth_cells : int = 20

var dormant_hordes : Array[Array] = []
var wake_index : int = 0


var renderer : EnemiesMultiMeshRenderer
var game_paused : bool = false

var _rng : RandomNumberGenerator = RandomNumberGenerator.new()
var _entry_pos : Vector2 = Vector2.ZERO
var _horde_centers : Array[Vector2] = []

# State read by the base-class hooks during a single spawn() call
var current_center : Vector2 = Vector2.ZERO
var current_resource : EnemyData = null
var current_horde : Array[Enemy] = []
var current_leader : Enemy = null
var spawned_count : int = 0
@onready var horde_manager : HordeManager = get_node_or_null("/root/World/HordesManager")


func _ready() -> void:
	super()  # camera + map_generated -> build_grid() -> setup_trigger()
	SignalManager.game_paused.connect(_on_game_paused)
	#max_enemy_count = 50 if GameMaster.game_mode == GameMaster.GAME_MODES.GOD else 20

	scene_to_spawn = ENEMY
	footprint = Vector2i.ONE
	occupy_cells = false        # stacking allowed: the flock spawns compact,

	avoid_camera_view = false  # min_distance_from_entry_px already handles it
	max_spawn_attempts = 30   # the pool is narrowed to the disc, so hits are cheap
	set_process(false)        # only runs while dormant hordes are being woken

## Dormant hordes: new centers far from the car, then one horde woken per frame
func _on_wake_trigger() -> void:
	var car : Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if car != null:
		_entry_pos = car.global_position
	_horde_centers.clear()
	_pick_periphery_centers()
	wake_index = 0
	set_process(true)


func _process(_delta : float) -> void:
	if game_paused:
		return
	# One horde per frame: the wake cost is spread, unseen since they are far from the car
	if wake_index < mini(dormant_hordes.size(), _horde_centers.size()):
		_wake_horde(dormant_hordes[wake_index], _horde_centers[wake_index])
		wake_index += 1
		return
	# Hordes without a center (map too small) are never used: freed
	for i : int in range(wake_index, dormant_hordes.size()):
		for enemy : Enemy in dormant_hordes[i]:
			if is_instance_valid(enemy):
				enemy.queue_free()
	dormant_hordes.clear()
	set_process(false)


func _wake_horde(horde : Array, center : Vector2) -> void:
	# The center is a free cell: the disc always holds at least that cell
	var cells : Array[Vector2i] = _cells_in_disc(center)
	for enemy : Enemy in horde:
		if !is_instance_valid(enemy):
			continue
		var cell : Vector2i = cells[_rng.randi() % cells.size()]
		enemy.wake((Vector2(cell) + Vector2.ONE * 0.5) * cell_size, chase_on_spawn)
		if horde_manager != null:
			horde_manager.count_enemies(1)
	if horde_manager != null:
		horde_manager.enemies_hordes.append(horde)

## Dormant hordes are moved on wake: any free cell will do, every horde is created
func _spawn_dormant_hordes() -> void:
	if free_cells.is_empty():
		push_warning("[HordeSpawner] no free cell, no dormant horde")
		return
	for i : int in nb_horde:
		var cell : Vector2i = free_cells[_rng.randi() % free_cells.size()]
		_spawn_horde((Vector2(cell) + Vector2.ONE * 0.5) * cell_size)


## Centers in the map edge band, away from the car. Car distance and spacing
## relax pass after pass instead of failing on a small map
func _pick_periphery_centers() -> void:
	var periphery : Array[Vector2i] = _periphery_cells()
	if periphery.is_empty():
		periphery = free_cells  # no edge band on this map: anywhere away from the car
	var car_distance : float = min_distance_from_entry_px
	var spacing : float = min_horde_spacing_px
	for relax_pass : int in 5:
		var attempts : int = 0
		while _horde_centers.size() < nb_horde and attempts < 400:
			attempts += 1
			var cell : Vector2i = periphery[_rng.randi() % periphery.size()]
			var pos : Vector2 = (Vector2(cell) + Vector2.ONE * 0.5) * cell_size
			if pos.distance_to(_entry_pos) < car_distance:
				continue
			if not _is_far_enough(pos, spacing):
				continue
			_horde_centers.append(pos)
		if _horde_centers.size() >= nb_horde:
			return
		car_distance *= 0.75
		spacing *= 0.75
	push_warning("[HordeSpawner] only %d/%d final hordes placed" % [_horde_centers.size(), nb_horde])


## Free cells of the outer band, between the building belt and the inner blocks
func _periphery_cells() -> Array[Vector2i]:
	var cells : Array[Vector2i] = []
	var map_size : Vector2i = map_bounds.size
	for cell : Vector2i in free_cells:
		var border_distance : int = mini(mini(cell.x, cell.y), mini(map_size.x - 1 - cell.x, map_size.y - 1 - cell.y))
		if border_distance <= periphery_depth_cells:
			cells.append(cell)
	return cells


func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause


# =================================================================
# BASE CLASS OVERRIDES
# =================================================================
func build_grid(data : MapData) -> void:
	super(data)
	if data == null:
		return
	_rng.seed = data.seed_used if use_map_seed else randi()
	_entry_pos = data.nodes[data.entry_node_idx] * float(data.cell_size)


func setup_trigger() -> void:
	# Called by Spawner._on_map_generated once free_cells is filled
	if not is_active:
		return
	if auto_spawn:
		_spawn_all_hordes()
		return
	if not SignalManager.has_signal(trigger_signal):
		push_error("[HordeSpawner] SignalManager has no signal '%s'" % trigger_signal)
		return
	# unbind() drops the signal's own arguments, whatever their count
	if prespawn_dormant:
		_spawn_dormant_hordes()
	var callback : Callable = _on_wake_trigger if prespawn_dormant else _on_trigger
	# unbind() drops the signal's own arguments; refused by Godot when there are none
	var arg_count : int = _signal_arg_count(trigger_signal)
	if arg_count > 0:
		callback = callback.unbind(arg_count)
	SignalManager.connect(trigger_signal, callback, CONNECT_ONE_SHOT)


func _spawn_all_hordes() -> void:
	if free_cells.is_empty():
		push_warning("[HordeSpawner] no free cell, nothing spawned")
		return
	spawned_count = 0
	_horde_centers.clear()
	_pick_centers()
	for center : Vector2 in _horde_centers:
		_spawn_horde(center)


func _on_trigger() -> void:
	# A late horde must keep away from the CAR, not from the entry: the same
	# min_distance_from_entry_px is reused around the car's current position
	var car : Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if car != null:
		_entry_pos = car.global_position
	_spawn_all_hordes()


func _signal_arg_count(signal_name : StringName) -> int:
	for info : Dictionary in SignalManager.get_signal_list():
		if info["name"] == signal_name:
			return (info["args"] as Array).size()
	return 0


func is_placement_valid(_anchor : Vector2i, _size : Vector2i, world_center : Vector2) -> bool:
	# A member only lands inside the disc of its own horde
	return world_center.distance_to(current_center) <= horde_radius_px


func configure_instance(instance : Node, _world_pos : Vector2) -> void:
	var enemy : Enemy = instance as Enemy
	if enemy == null:
		return
	enemy.enemy = current_resource
	enemy.renderer = renderer
	enemy.horde = current_horde          # shared array, appended in on_spawned
	enemy.is_leader = current_horde.is_empty()  # first spawned member leads
	if prespawn_dormant:
		# Set before add_child: _ready skips the renderer, the node stays out of process and physics
		enemy.dormant = true
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	if enemy.is_leader:
		current_leader = enemy
		set_leader(enemy)


func on_spawned(instance : Node) -> void:
	# global_position is already set by Spawner.spawn() at this point
	var enemy : Enemy = instance as Enemy
	if enemy == null:
		return
	current_horde.append(enemy)
	spawned_count += 1
	if enemy.dormant:
		return  # counted, rendered and activated on wake
	if horde_manager != null:
		horde_manager.count_enemies(1)
	# Same order as the stream spawner: state first, then activation
	if chase_on_spawn:
		enemy.state_machine.state_transition_to("chase")
	enemy.activate(enemy.global_position)


# =================================================================
# HORDES
# =================================================================
func _pick_centers() -> void:
	# Rejection sampling over the base free cells. Spacing is relaxed by passes
	# if the map cannot host nb_horde centres, instead of looping forever.
	var spacing : float = min_horde_spacing_px
	for relax_pass : int in 5:
		var attempts : int = 0
		while _horde_centers.size() < nb_horde and attempts < 400:
			attempts += 1
			var cell : Vector2i = free_cells[_rng.randi() % free_cells.size()]
			var pos : Vector2 = (Vector2(cell) + Vector2.ONE * 0.5) * cell_size
			if pos.distance_to(_entry_pos) < min_distance_from_entry_px:
				continue
			if not _is_far_enough(pos, spacing):
				continue
			_horde_centers.append(pos)
		if _horde_centers.size() >= nb_horde:
			return
		spacing *= 0.75

	push_warning("[HordeSpawner] only %d/%d hordes placed" % [_horde_centers.size(), nb_horde])


func _is_far_enough(pos : Vector2, spacing : float) -> bool:
	for center : Vector2 in _horde_centers:
		if pos.distance_to(center) < spacing:
			return false
	return true


func _spawn_horde(center : Vector2) -> void:
	current_center = center
	current_resource = EnemyManager.Enemy_ressources[enemy_type]
	current_horde = []   # new array per horde: enemies keep their own reference
	current_leader = null

	# Narrow the base-class pool to the horde disc: pick_random() then always
	# lands inside it. Safe because occupy_cells is false, nothing is consumed.
	var full_cells : Array[Vector2i] = free_cells
	free_cells = _cells_in_disc(center)
	if free_cells.is_empty():
		free_cells = full_cells
		push_warning("[HordeSpawner] no free cell around %s" % center)
		return

	for i : int in max_enemy_count:
		if spawn() == null:
			continue

	free_cells = full_cells

	for enemy : Enemy in current_horde:
		enemy.leader = null if enemy == current_leader else current_leader

	if prespawn_dormant:
		dormant_hordes.append(current_horde)
	elif horde_manager != null:
		horde_manager.enemies_hordes.append(current_horde)


func set_leader(_leader : Enemy) -> void:
	pass

func _cells_in_disc(center : Vector2) -> Array[Vector2i]:
	# Free cells whose centre falls inside the horde radius. Scans only the
	# bounding box of the disc, so it stays cheap whatever the map size.
	var cells : Array[Vector2i] = []
	var radius_cells : int = int(ceil(horde_radius_px / cell_size))
	var center_cell : Vector2i = Vector2i(floor(center.x / cell_size), floor(center.y / cell_size))
	for dy : int in range(-radius_cells, radius_cells + 1):
		for dx : int in range(-radius_cells, radius_cells + 1):
			var cell : Vector2i = center_cell + Vector2i(dx, dy)
			if not free_cell_set.has(cell):
				continue
			var pos : Vector2 = (Vector2(cell) + Vector2.ONE * 0.5) * cell_size
			if pos.distance_to(center) <= horde_radius_px:
				cells.append(cell)
	return cells
