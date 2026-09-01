extends Node2D

@export var effects: Array[VFXData] = []

func _ready() -> void:
	play_all()

func play_all() -> void:
	for effect in effects:
		if effect.delay > 0.0:
			play_with_delay(effect)
		else:
			play_effect(effect)

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
		push_warning("Effet '%s' : aucun node de particules trouvé" % effect.nom)
		return
	node.restart()
	node.emitting = true

func play_shader(effect: VFXData) -> void:
	var node: Node = get_node_or_null(effect.shader_node)
	if node == null or node.material == null:
		push_warning("Effet '%s' : node ou material manquant" % effect.nom)
		return

	var mat: ShaderMaterial = node.material
	var t: float = 0.0
	mat.set_shader_parameter(effect.shader_uniform_progress, 0.0)

	while t < effect.shader_duree:
		t += get_process_delta_time()
		var progress: float = clamp(t / effect.shader_duree, 0.0, 1.0)
		mat.set_shader_parameter(effect.shader_uniform_progress, progress)
		await get_tree().process_frame
