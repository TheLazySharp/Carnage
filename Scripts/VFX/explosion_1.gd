@tool
extends Node2D

@export var effects: Array[VFXData] = []

@export_tool_button("Play VFX", "Play")
var bouton_play := play_all


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	play_all()


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event.is_action_pressed("dash") or event.is_action_pressed("ui_select"):
		play_all()

func play_all() -> void:
	for effect in effects:
		if effect.delay > 0.0:
			play_with_delay(effect)
		else:
			play_effect(effect)
	print("explosion 1 played")

func play_with_delay(effect: VFXData) -> void:
	await get_tree().create_timer(effect.delay).timeout
	play_effect(effect)

func play_effect(effect: VFXData) -> void:
	match effect.type:
		VFXData.Type.ANIMATION:
			play_animation(effect)
		VFXData.Type.PARTICLES:
			play_particles(effect)
		VFXData.Type.SHADER:
			play_shader(effect)

func play_animation(effect: VFXData) -> void:
	if effect.variantes_animation.is_empty():
		push_warning("Effet '%s' : aucune variante d'animation assignée" % effect.nom)
		return

	var sprites: Array[AnimatedSprite2D] = []
	for path in effect.variantes_animation:
		var node: Node = get_node_or_null(path)
		if node is AnimatedSprite2D:
			sprites.append(node)
		else:
			push_warning("Effet '%s' : chemin invalide ou node pas un AnimatedSprite2D (%s)" % [effect.nom, path])

	if sprites.is_empty():
		return

	for s in sprites:
		s.stop()
		s.visible = false

	var choix: AnimatedSprite2D = sprites[randi() % sprites.size()]
	choix.visible = true
	choix.frame = 0
	choix.play()

func play_particles(effect: VFXData) -> void:
	var node: Node = get_node_or_null(effect.particles)
	if node == null:
		push_warning("Effet '%s' : aucun node de particules trouvé" % effect.name)
		return
	node.restart()
	node.emitting = true

func play_shader(effect: VFXData) -> void:
	var node: Node = get_node_or_null(effect.shader_node)
	if node == null or node.material == null:
		push_warning("Effet '%s' : node ou material manquant" % effect.name)
		return
	var mat: ShaderMaterial = node.material
	if node is CanvasItem:
		node.visible = true
	var t: float = 0.0
	mat.set_shader_parameter(effect.shader_uniform_progress, 0.0)
	_update_shader_center(effect, mat)
	while t < effect.shader_duree:
		await get_tree().process_frame
		t += get_process_delta_time()
		var progress: float = clamp(t / effect.shader_duree, 0.0, 1.0)
		mat.set_shader_parameter(effect.shader_uniform_progress, progress)
		_update_shader_center(effect, mat)
	if node is CanvasItem:
		node.visible = false
	mat.set_shader_parameter(effect.shader_uniform_progress, 0.0)


func _update_shader_center(effect: VFXData, mat: ShaderMaterial) -> void:
	if effect.shader_uniform_center.is_empty():
		return
	var vp_size: Vector2 = get_viewport_rect().size
	var canvas_pos: Vector2 = get_global_transform_with_canvas().origin
	mat.set_shader_parameter(effect.shader_uniform_center, canvas_pos / vp_size)
