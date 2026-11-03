extends Node2D
class_name TracerPreview2D

## Scène dont la racine est un TracerTrail2D configuré (gradient, épaisseur, vitesse...).
@export var trail_scene: PackedScene

@export_group("Projectile")
## Sprite fixe du projectile (ignoré si projectile_frames est renseigné).
@export var projectile_texture: Texture2D
## Sprite animé du projectile : prioritaire sur la texture simple.
@export var projectile_frames: SpriteFrames
@export var projectile_animation: StringName = &"default"
## Scène de particules qui suit le projectile (peut contenir plusieurs
## GPUParticles2D / CPUParticles2D). À dessiner avec le projectile orienté vers la
## droite (+X), et "Local Coords" désactivé si tu veux laisser un sillage dans le monde.
@export var projectile_particles: PackedScene
@export var rotate_sprite_to_direction: bool = true
## Si ton sprite est dessiné pointant vers le haut, mets 90.
@export var sprite_angle_offset_degrees: float = 0.0

class Shot:
	var holder: Node2D
	var visual: Node2D
	var origin: Vector2
	var direction: Vector2
	var traveled: float = 0.0
	var speed: float = 0.0
	var max_range: float = 0.0
	var snap: float = 1.0

var _shots: Array[Shot] = []
var _was_pressed: bool = false


func _process(delta: float) -> void:
	var pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if pressed and not _was_pressed:
		_fire(get_global_mouse_position())
	_was_pressed = pressed

	_update_shots(delta)


## Le tir part de la position de ce node, vers le point cliqué.
func _fire(target: Vector2) -> void:
	if trail_scene == null:
		push_warning("TracerPreview2D: assigne trail_scene.")
		return

	var origin: Vector2 = global_position
	var to_target: Vector2 = target - origin
	if to_target.length_squared() < 1.0:
		return
	var dir: Vector2 = to_target.normalized()

	var host: Node = get_tree().current_scene
	if host == null:
		host = self

	var trail: TracerTrail2D = trail_scene.instantiate() as TracerTrail2D
	if trail == null:
		push_warning("TracerPreview2D: la racine de trail_scene doit être un TracerTrail2D.")
		return
	host.add_child(trail)
	trail.launch(origin, dir)

	if projectile_frames == null and projectile_texture == null and projectile_particles == null:
		return

	# Le holder porte la direction : les particules enfants suivent l'orientation du tir.
	var holder := Node2D.new()
	holder.top_level = true
	holder.rotation = dir.angle()
	host.add_child(holder)
	holder.global_position = trail.global_position

	var visual: Node2D = _make_visual()
	if visual != null:
		if rotate_sprite_to_direction:
			visual.rotation = deg_to_rad(sprite_angle_offset_degrees)
		else:
			visual.rotation = -dir.angle()
		holder.add_child(visual)

	if projectile_particles != null:
		var fx: Node = projectile_particles.instantiate()
		holder.add_child(fx)

	var shot := Shot.new()
	shot.holder = holder
	shot.visual = visual
	shot.origin = trail.global_position
	shot.direction = dir
	shot.speed = trail.projectile_speed
	shot.max_range = trail.max_range
	shot.snap = float(trail.pixel_size)
	_shots.append(shot)


func _make_visual() -> Node2D:
	if projectile_frames != null:
		var anim_name: StringName = projectile_animation
		if not projectile_frames.has_animation(anim_name):
			var names: PackedStringArray = projectile_frames.get_animation_names()
			if names.is_empty():
				return null
			anim_name = StringName(names[0])
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = projectile_frames
		anim.animation = anim_name
		anim.autoplay = String(anim_name)
		return anim

	if projectile_texture != null:
		var spr := Sprite2D.new()
		spr.texture = projectile_texture
		return spr

	return null


func _update_shots(delta: float) -> void:
	for i: int in range(_shots.size() - 1, -1, -1):
		var s: Shot = _shots[i]
		s.traveled += s.speed * delta

		if s.traveled >= s.max_range:
			_finish_shot(s)
			_shots.remove_at(i)
			continue

		if is_instance_valid(s.holder):
			var p: Vector2 = s.origin + s.direction * s.traveled
			s.holder.global_position = p.snapped(Vector2(s.snap, s.snap))


## Cache le sprite, coupe l'émission, et laisse les particules restantes
## finir leur vie avant de supprimer le projectile.
func _finish_shot(s: Shot) -> void:
	if not is_instance_valid(s.holder):
		return

	if is_instance_valid(s.visual):
		s.visual.hide()

	var emitters: Array[Node] = s.holder.find_children("*", "GPUParticles2D", true, false)
	emitters.append_array(s.holder.find_children("*", "CPUParticles2D", true, false))

	var linger: float = 0.0
	for e: Node in emitters:
		if e is GPUParticles2D:
			var gp: GPUParticles2D = e as GPUParticles2D
			gp.emitting = false
			linger = maxf(linger, gp.lifetime / maxf(gp.speed_scale, 0.001))
		elif e is CPUParticles2D:
			var cp: CPUParticles2D = e as CPUParticles2D
			cp.emitting = false
			linger = maxf(linger, cp.lifetime / maxf(cp.speed_scale, 0.001))

	if linger <= 0.0:
		s.holder.queue_free()
	else:
		get_tree().create_timer(linger).timeout.connect(s.holder.queue_free)
