extends Node2D

# Glisse-dépose tes nodes ici depuis l'arborescence, dans l'inspecteur
@export var sprite_1: AnimatedSprite2D
@export var sprite_2: AnimatedSprite2D
@export var sprite_3: AnimatedSprite2D
@export var particles: Node # CPUParticles2D ou GPUParticles2D, les deux ont "emitting" et "restart()"

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_select"): # touche Espace
		jouer_effet_hit()

func jouer_effet_hit() -> void:
	# Cache les 3 sprites, puis n'affiche/joue que celui tiré au sort
	var sprites: Array[AnimatedSprite2D] = [sprite_1, sprite_2, sprite_3]
	for s in sprites:
		s.stop()
		s.visible = false

	var choix: AnimatedSprite2D = sprites[randi() % sprites.size()]
	choix.visible = true
	choix.frame = 0
	choix.play()

	# Redémarre l'émission de particules à chaque hit
	particles.restart()
	particles.emitting = true
