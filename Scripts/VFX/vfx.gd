extends Node2D
## Global VFX autoload. Shared, never restarted GPUParticles2D emitters fed with
## emit_particle(): the GPU object count and the draw call / dispatch count do
## not depend on how many effects are playing. The budget below is CPU side
## (one GDScript call per particle), which is the actual bottleneck.
## The emitter node must stay at (0,0) with no rotation/scale: positions and
## velocities are passed in world space.

## emit_particle() calls allowed per frame for blood, all impacts together
const BLOOD_BUDGET : int = 256
## Pending impacts kept in the delay queue at most
const BLOOD_QUEUE_MAX : int = 64
## Delay between the impact flash and the blood burst (was 0.133 s in the AnimationPlayer)
const BLOOD_DELAY : float = 0.133
## Extra margin around the camera rect before culling a request
const CULL_MARGIN : float = 192.0
## Particles per impact at full quality (original scene: 7 / 75 / 8 / 3x4)
const IMPACT_COUNT : int = 3
const DROPS_COUNT : int = 32
const TRAILS_COUNT : int = 4
const BLOBS_COUNT_PER_EMITTER : int = 2
## Copied from the original ParticleProcessMaterials / node offsets
const DROPS_SPREAD : float = 0.3509      # 20.107 deg
const DROPS_SPEED_MIN : float = 67.47
const DROPS_SPEED_MAX : float = 371.24
const DROPS_OFFSET : float = 6.685       # emission_shape_offset.x
const BLOBS_SPREAD : float = 0.4345      # 24.893 deg
const BLOBS_SPEED_MIN : float = 23.81
const BLOBS_SPEED_MAX : float = 300.17
const BLOBS_OFFSET : float = 13.0        # BloodBlobs node position.x
const EMIT_POS : int = GPUParticles2D.EMIT_FLAG_POSITION
const EMIT_POS_VEL : int = GPUParticles2D.EMIT_FLAG_POSITION | GPUParticles2D.EMIT_FLAG_VELOCITY

@onready var _blood_impact : GPUParticles2D = $BloodImpact
@onready var _blood_drops : GPUParticles2D = $BloodDrops
@onready var _blood_trails : GPUParticles2D = $BloodTrails
@onready var _blood_blobs : Array[GPUParticles2D] = [$BloodBlobs1, $BloodBlobs2, $BloodBlobs3, $BloodBlobs4]

var _rng : RandomNumberGenerator = RandomNumberGenerator.new()
var _view_rect : Rect2 = Rect2()
var _has_view : bool = false
var _blood_pos : PackedVector2Array = PackedVector2Array()
var _blood_dir : PackedVector2Array = PackedVector2Array()
var _blood_due : PackedFloat32Array = PackedFloat32Array()
var _blood_clock : float = 0.0
var _blood_budget_left : int = BLOOD_BUDGET


func _ready() -> void:
	_rng.randomize()
	process_priority = 100  # flush after gameplay nodes
	_warm_up()


func _process(delta : float) -> void:
	_update_view()
	_flush_blood(delta)


## Public API, callable from any scene: Vfx.blood_impact(global_position, spray_dir)
## spray_dir: direction the blood flies (projectile direction). In the old scene
## it was -X of the rotated ImpactOnEnemy root.
func blood_impact(world_pos : Vector2, spray_dir : Vector2) -> void:
	if _has_view and not _view_rect.has_point(world_pos):
		return  # off screen: nothing at all
	if _blood_pos.size() >= BLOOD_QUEUE_MAX:
		return
	var dir : Vector2 = Vector2.LEFT if spray_dir.is_zero_approx() else spray_dir.normalized()
	# Impact flash right away, POSITION only: the material picks a random frame
	var xform : Transform2D = Transform2D(0.0, world_pos)
	for i : int in IMPACT_COUNT:
		_blood_impact.emit_particle(xform, Vector2.ZERO, Color.WHITE, Color.BLACK, EMIT_POS)
	# Blood burst is delayed like the original AnimationPlayer track
	_blood_pos.append(world_pos)
	_blood_dir.append(dir)
	_blood_due.append(_blood_clock + BLOOD_DELAY)


func _flush_blood(delta : float) -> void:
	_blood_clock += delta
	var count : int = _blood_pos.size()
	if count == 0:
		return
	# Requests are appended in time order with the same delay: the due ones are a prefix
	var ready_count : int = 0
	while ready_count < count and _blood_due[ready_count] <= _blood_clock:
		ready_count += 1
	if ready_count == 0:
		return
	_blood_budget_left = BLOOD_BUDGET
	# Over budget: thin every impact out instead of dropping some of them
	var full_cost : int = DROPS_COUNT + TRAILS_COUNT + BLOBS_COUNT_PER_EMITTER * 4
	var quality : float = clampf(float(BLOOD_BUDGET) / float(ready_count * full_cost), 0.2, 1.0)
	for i : int in ready_count:
		if _blood_budget_left <= 0:
			break
		_spawn_blood(_blood_pos[i], _blood_dir[i], quality)
	if ready_count == count:
		_blood_pos.clear()
		_blood_dir.clear()
		_blood_due.clear()
	else:
		_blood_pos = _blood_pos.slice(ready_count)
		_blood_dir = _blood_dir.slice(ready_count)
		_blood_due = _blood_due.slice(ready_count)


func _spawn_blood(world_pos : Vector2, dir : Vector2, quality : float) -> void:
	var drops : int = maxi(2, int(float(DROPS_COUNT) * quality))
	var trails : int = maxi(1, int(float(TRAILS_COUNT) * quality))
	var blobs : int = maxi(1, int(float(BLOBS_COUNT_PER_EMITTER) * quality))
	_blood_budget_left -= drops + trails + blobs * 4

	var xform : Transform2D = Transform2D(0.0, world_pos + dir * DROPS_OFFSET)
	for i : int in drops:
		_blood_drops.emit_particle(xform,
			_spray_velocity(dir, DROPS_SPREAD, DROPS_SPEED_MIN, DROPS_SPEED_MAX),
			Color.WHITE, Color.BLACK, EMIT_POS_VEL)
	for i : int in trails:
		_blood_trails.emit_particle(xform,
			_spray_velocity(dir, DROPS_SPREAD, DROPS_SPEED_MIN, DROPS_SPEED_MAX),
			Color.WHITE, Color.BLACK, EMIT_POS_VEL)

	xform.origin = world_pos + dir * BLOBS_OFFSET
	for emitter : GPUParticles2D in _blood_blobs:
		for i : int in blobs:
			emitter.emit_particle(xform,
				_spray_velocity(dir, BLOBS_SPREAD, BLOBS_SPEED_MIN, BLOBS_SPEED_MAX),
				Color.WHITE, Color.BLACK, EMIT_POS_VEL)


## Reproduces ParticleProcessMaterial direction + spread + initial_velocity
func _spray_velocity(dir : Vector2, spread : float, speed_min : float, speed_max : float) -> Vector2:
	return dir.rotated(_rng.randf_range(-spread, spread)) * _rng.randf_range(speed_min, speed_max)


func _update_view() -> void:
	var cam : Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		_has_view = false
		return
	var size : Vector2 = get_viewport_rect().size / cam.zoom
	_view_rect = Rect2(cam.get_screen_center_position() - size * 0.5, size).grow(CULL_MARGIN)
	_has_view = true


## Forces shader compilation and GPU buffer allocation before the first use,
## otherwise the very first emission of each emitter hitches.
func _warm_up() -> void:
	var far : Transform2D = Transform2D(0.0, Vector2(-100000.0, -100000.0))
	_blood_impact.emit_particle(far, Vector2.ZERO, Color.WHITE, Color.BLACK, EMIT_POS)
	_blood_drops.emit_particle(far, Vector2.ZERO, Color.WHITE, Color.BLACK, EMIT_POS_VEL)
	_blood_trails.emit_particle(far, Vector2.ZERO, Color.WHITE, Color.BLACK, EMIT_POS_VEL)
	for emitter : GPUParticles2D in _blood_blobs:
		emitter.emit_particle(far, Vector2.ZERO, Color.WHITE, Color.BLACK, EMIT_POS_VEL)
