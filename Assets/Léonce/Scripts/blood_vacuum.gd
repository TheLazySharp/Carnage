extends CanvasGroup

# Vitesse du fade automatique (en secondes entre chaque frame)
@export var vitesse_fade: float = 0.1

# Variables internes, ne pas toucher
var nombre_frames: int = 0
var frame_actuelle: int = 0
var fade_en_cours: bool = false
var timer_fade: float = 0.0

func _ready() -> void:
	# Calcul automatique de la taille englobante des sprites enfants (les splatters),
	# pour que le shader puisse corriger l'aspect ratio du masque
	var bounds: Rect2 = Rect2()
	var first := true
	for child in get_children():
		if child is Sprite2D:
			var tex_size: Vector2 = child.texture.get_size() * child.scale
			var child_rect := Rect2(child.position - tex_size * 0.5, tex_size)
			if first:
				bounds = child_rect
				first = false
			else:
				bounds = bounds.merge(child_rect)

	material.set_shader_parameter("container_size", bounds.size)

	# Lecture du nombre de frames et initialisation à la frame 0
	nombre_frames = material.get_shader_parameter("frame_count")
	frame_actuelle = 0
	material.set_shader_parameter("current_frame", frame_actuelle)

func _process(delta: float) -> void:
	if fade_en_cours:
		timer_fade += delta
		if timer_fade >= vitesse_fade:
			timer_fade = 0.0
			avancer_frame(1)
			if frame_actuelle >= nombre_frames - 1:
				fade_en_cours = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		avancer_frame(1)

	if event.is_action_pressed("ui_left"):
		avancer_frame(-1)

	if event.is_action_pressed("ui_select"): # Espace
		fade_en_cours = true
		timer_fade = 0.0

	if event.is_action_pressed("ui_cancel"): # Echap
		frame_actuelle = 0
		material.set_shader_parameter("current_frame", frame_actuelle)
		fade_en_cours = false

func avancer_frame(direction: int) -> void:
	frame_actuelle = clamp(frame_actuelle + direction, 0, nombre_frames - 1)
	material.set_shader_parameter("current_frame", frame_actuelle)
