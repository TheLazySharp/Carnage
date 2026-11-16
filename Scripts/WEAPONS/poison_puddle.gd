extends Node2D
class_name PoisonPuddle
## Poison puddle left by a poison vial. Drawn like the enemies blood splatter (one main splat + scattered drops),
## it poisons the enemies walking in. After `charges` different enemies poisoned, it darkens and poisons no more

@export_group("Poison")
@export var charges : int = 10                              # different enemies poisoned before the puddle is spent
@export var base_color : Color = Color.WHITE:               # modulate of a fresh puddle
	set(value):
		base_color = value
		modulate = base_color
@export var spent_color : Color = Color(0.3, 0.35, 0.25)    # modulate once spent (darker)
@export var spent_linger : float = 0.0                      # seconds a spent puddle stays before freeing itself (0 = stays)

@export_group("Textures")
## One texture per splat, loaded from these folders (blood ones by default: white, tinted by base_color)
@export_dir var main_folder : String = "res://Assets/VFX/BloodPools/BloodPoolMain/"
@export_dir var big_folder : String = "res://Assets/VFX/BloodPools/BloodPoolBig/"
@export_dir var small_folder : String = "res://Assets/VFX/BloodPools/BloodPoolSmall/"

## Folder path -> its textures, loaded once for every puddle
static var folder_cache : Dictionary[String, Array] = {}

@export_group("Quantity")
@export_range(1, 10, 1) var big_count_min : int = 1
@export_range(1, 10, 1) var big_count_max : int = 3
@export_range(1, 30, 1) var small_count_min : int = 3
@export_range(1, 30, 1) var small_count_max : int = 6

@export_group("Placement")
@export_range(1, 16, 1) var pixel_size : int = 1
@export_range(0, 128, 1) var big_scatter_radius : int = 8
@export_range(0, 256, 1) var small_scatter_radius : int = 14
@export_range(0, 64, 1) var min_distance : int = 3

@export_group("Rotation")
@export var constrain_rotation_90 : bool = false
@export var allow_flip : bool = true

@export_group("Timing")
@export_range(0.0, 3.0, 0.01) var spawn_duration : float = 0.25

@onready var poison_area : Area2D = $PoisonArea

var status_duration : float = 3.0
var status_power : float = 1.0
var charges_left : int = 0
var poisoned_enemies : Array[Enemy] = []   # each enemy counts once
var rng : RandomNumberGenerator = RandomNumberGenerator.new()
var placed_positions : Array[Vector2] = []


func _ready() -> void:
	rng.randomize()
	modulate = base_color
	charges_left = charges
	poison_area.area_entered.connect(_on_area_entered)
	_spawn_sequence()


## Called by the vial right after add_child(): the poison of its impact (combo snapshot included)
func setup(p_duration : float, p_power : float) -> void:
	status_duration = p_duration
	status_power = p_power


# ---------------- POISON ----------------

func _on_area_entered(area : Area2D) -> void:
	if charges_left <= 0:
		return
	# The enemy root area or one of its child areas (hitbox): both resolve to the enemy
	var enemy : Enemy = area as Enemy
	if enemy == null:
		enemy = area.get_parent() as Enemy
	if enemy == null or enemy.is_dead or poisoned_enemies.has(enemy):
		return
	poisoned_enemies.append(enemy)
	enemy.apply_status(EnemyManager.Status.POISON, status_duration, status_power)
	charges_left -= 1
	if charges_left <= 0:
		_spend()


## No charge left: darker, poisons no more
func _spend() -> void:
	poison_area.set_deferred("monitoring", false)
	modulate = spent_color
	poisoned_enemies.clear()
	if spent_linger > 0.0:
		get_tree().create_timer(spent_linger, false).timeout.connect(queue_free)


# ---------------- VISUAL (same scatter as the blood splatter) ----------------

func _spawn_sequence() -> void:
	# Splats loaded from the texture folders (white: tinted by base_color)
	var mains : Array[Texture2D] = _load_folder(main_folder)
	var bigs : Array[Texture2D] = _load_folder(big_folder)
	var smalls : Array[Texture2D] = _load_folder(small_folder)
	var pending : Array[Dictionary] = []
	if !mains.is_empty():
		pending.append({"texture": mains[rng.randi_range(0, mains.size() - 1)], "position": Vector2.ZERO, "main": true})
		placed_positions.append(Vector2.ZERO)
	if !bigs.is_empty():
		for i : int in rng.randi_range(big_count_min, big_count_max):
			var pos : Vector2 = _find_scatter_position(big_scatter_radius)
			placed_positions.append(pos)
			pending.append({"texture": bigs[rng.randi_range(0, bigs.size() - 1)], "position": pos, "main": false})
	if !smalls.is_empty():
		for i : int in rng.randi_range(small_count_min, small_count_max):
			var pos : Vector2 = _find_scatter_position(small_scatter_radius)
			placed_positions.append(pos)
			pending.append({"texture": smalls[rng.randi_range(0, smalls.size() - 1)], "position": pos, "main": false})
	if pending.is_empty():
		push_warning("PoisonPuddle: no texture set")
		return
	var delay_between : float = spawn_duration / float(pending.size())
	for splat : Dictionary in pending:
		_add_splat(splat)
		if delay_between > 0.0:
			# process_always = false: the spreading waits during the pause menu
			await get_tree().create_timer(delay_between, false).timeout
			if !is_inside_tree():
				return

func _add_splat(splat : Dictionary) -> void:
	var sprite : Sprite2D = Sprite2D.new()
	sprite.texture = splat["texture"]
	sprite.position = splat["position"]
	if !splat["main"]:
		if constrain_rotation_90:
			sprite.rotation = rng.randi_range(0, 3) * (PI / 2.0)
		else:
			sprite.rotation = rng.randf_range(0, TAU)
		if allow_flip:
			sprite.flip_h = rng.randi_range(0, 1) == 1
			sprite.flip_v = rng.randi_range(0, 1) == 1
	add_child(sprite)


func _find_scatter_position(radius : int) -> Vector2:
	var min_dist_px : float = min_distance * pixel_size
	for attempt : int in 20:
		var angle : float = rng.randf_range(0, TAU)
		var candidate : Vector2 = Vector2(cos(angle), sin(angle)) * rng.randf_range(0, radius) * pixel_size
		if min_distance <= 0:
			return _snap(candidate)
		var too_close : bool = false
		for existing : Vector2 in placed_positions:
			if candidate.distance_to(existing) < min_dist_px:
				too_close = true
				break
		if !too_close:
			return _snap(candidate)
	var fallback_angle : float = rng.randf_range(0, TAU)
	return _snap(Vector2(cos(fallback_angle), sin(fallback_angle)) * radius * pixel_size)


func _snap(pos : Vector2) -> Vector2:
	if pixel_size <= 1:
		return pos.round()
	return (pos / pixel_size).round() * pixel_size


## Every texture of a folder, loaded once and shared by all the puddles.
## ResourceLoader.list_directory() also works in an exported game (imported files)
static func _load_folder(folder : String) -> Array[Texture2D]:
	if folder_cache.has(folder):
		return folder_cache[folder]
	var textures : Array[Texture2D] = []
	for file : String in ResourceLoader.list_directory(folder):
		var texture : Texture2D = load(folder.path_join(file)) as Texture2D
		if texture != null:
			textures.append(texture)
	if textures.is_empty():
		push_warning("PoisonPuddle: no texture in " + folder)
	folder_cache[folder] = textures
	return textures
