extends Spawner
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

@onready var horde_manager : HordeManager = get_node_or_null("/root/World/HordesManager")


func _ready() -> void:
	super()  # camera + map_generated -> build_grid() -> setup_trigger()
	SignalManager.game_paused.connect(_on_game_paused)
	max_enemy_count = 50 if GameMaster.game_mode == GameMaster.GAME_MODES.GOD else 20

	scene_to_spawn = ENEMY
	footprint = Vector2i.ONE
	occupy_cells = false        # stacking allowed: the flock spawns compact,
							   # IDLE wandering spreads it out afterwards
	avoid_camera_view = false  # min_distance_from_entry_px already handles it
	max_spawn_attempts = 30   # the pool is narrowed to the disc, so hits are cheap


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
	if free_cells.is_empty():
		push_warning("[HordeSpawner] no free cell, nothing spawned")
		return

	_horde_centers.clear()
	_pick_centers()
	for center : Vector2 in _horde_centers:
		_spawn_horde(center)

	print("[HordeSpawner] ", _horde_centers.size(), " hordes of ",
			max_enemy_count, " enemies")


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
	if enemy.is_leader:
		current_leader = enemy
		set_leader(enemy)


func on_spawned(instance : Node) -> void:
	# global_position is already set by Spawner.spawn() at this point
	var enemy : Enemy = instance as Enemy
	if enemy == null:
		return
	if horde_manager != null:
		horde_manager.count_enemies(1)
	current_horde.append(enemy)
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

	if horde_manager != null:
		horde_manager.enemies_hordes.append(current_horde)


func set_leader(_leader : Enemy) -> void:
	#leader.set_enemy_color(Color.BLACK)
	#leader.max_life = 2
	#leader.damages_on_player = 5
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
