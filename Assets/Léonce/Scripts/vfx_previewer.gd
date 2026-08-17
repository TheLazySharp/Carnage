extends Node2D

@export var effets: Array[VFXEntry] = []

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_select"):
		jouer_tous_les_effets()

func jouer_tous_les_effets() -> void:
	for effet in effets:
		if effet.delay > 0.0:
			_jouer_avec_delay(effet)
		else:
			_jouer_effet(effet)

func _jouer_avec_delay(effet: VFXEntry) -> void:
	await get_tree().create_timer(effet.delay).timeout
	_jouer_effet(effet)

func _jouer_effet(effet: VFXEntry) -> void:
	match effet.type:
		VFXEntry.Type.ANIMATION:
			_jouer_animation(effet)
		VFXEntry.Type.PARTICLES:
			_jouer_particles(effet)
		VFXEntry.Type.SHADER:
			_jouer_shader(effet)

func _jouer_animation(effet: VFXEntry) -> void:
	if effet.variantes_animation.is_empty():
		push_warning("Effet '%s' : aucune variante d'animation assignée" % effet.nom)
		return

	var sprites: Array[AnimatedSprite2D] = []
	for path in effet.variantes_animation:
		var node: Node = get_node_or_null(path)
		if node is AnimatedSprite2D:
			sprites.append(node)
		else:
			push_warning("Effet '%s' : chemin invalide ou node pas un AnimatedSprite2D (%s)" % [effet.nom, path])

	if sprites.is_empty():
		return

	for s in sprites:
		s.stop()
		s.visible = false

	var choix: AnimatedSprite2D = sprites[randi() % sprites.size()]
	choix.visible = true
	choix.frame = 0
	choix.play()

func _jouer_particles(effet: VFXEntry) -> void:
	var node: Node = get_node_or_null(effet.particles)
	if node == null:
		push_warning("Effet '%s' : aucun node de particules trouvé" % effet.nom)
		return
	node.restart()
	node.emitting = true

func _jouer_shader(effet: VFXEntry) -> void:
	var node: Node = get_node_or_null(effet.shader_node)
	if node == null or node.material == null:
		push_warning("Effet '%s' : node ou material manquant" % effet.nom)
		return

	var mat: ShaderMaterial = node.material
	var t: float = 0.0
	mat.set_shader_parameter(effet.shader_uniform_progress, 0.0)

	while t < effet.shader_duree:
		t += get_process_delta_time()
		var progress: float = clamp(t / effet.shader_duree, 0.0, 1.0)
		mat.set_shader_parameter(effet.shader_uniform_progress, progress)
		await get_tree().process_frame
