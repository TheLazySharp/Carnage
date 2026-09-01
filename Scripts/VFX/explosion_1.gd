@tool
extends Node2D

@export var effects: Array[VFXData] = []

@export_tool_button("Play VFX", "Play")
var bouton_play := play_all

var game_paused : bool = false
var _vitesses_originales: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	SignalManager.game_paused.connect(_on_game_paused)
	play_all()


func play_all() -> void:
	for effect in effects:
		if effect.delay > 0.0:
			play_with_delay(effect)
		else:
			play_effect(effect)
	print("explosion 1 played")

func play_with_delay(effect: VFXData) -> void:
	var t: float = 0.0
	while t < effect.delay:
		await get_tree().process_frame
		if game_paused:
			continue
		t += get_process_delta_time()
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
		push_warning("Effet '%s' : aucune variante d'animation assignée" % effect.name)
		return

	var sprites: Array[AnimatedSprite2D] = []
	for path in effect.variantes_animation:
		var node: Node = get_node_or_null(path)
		if node is AnimatedSprite2D:
			sprites.append(node)
		else:
			push_warning("Effet '%s' : chemin invalide ou node pas un AnimatedSprite2D (%s)" % [effect.name, path])

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
		if game_paused:
			continue
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

func _vitesse_originale(n: Node) -> float:
	if !_vitesses_originales.has(n):
		_vitesses_originales[n] = n.speed_scale
	return _vitesses_originales[n]

func _on_game_paused(game_on_pause: bool) -> void:
	game_paused = game_on_pause
	for effect in effects:
		match effect.type:
			VFXData.Type.ANIMATION:
				for path in effect.variantes_animation:
					var node: Node = get_node_or_null(path)
					if node is AnimatedSprite2D:
						var speed: float = _vitesse_originale(node)
						node.speed_scale = 0.0 if game_on_pause else speed
			VFXData.Type.PARTICLES:
				var particle: Node = get_node_or_null(effect.particles)
				if particle != null:
					var speed: float = _vitesse_originale(particle)
					particle.speed_scale = 0.0 if game_on_pause else speed
