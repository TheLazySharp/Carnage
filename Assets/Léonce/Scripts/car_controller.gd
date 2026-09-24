extends Sprite2D

## Contrôleur minimal (flèches directionnelles) pour tester le POC d'afterimage
## directement sur un Sprite2D, sans CharacterBody2D. À attacher au Sprite2D
## qui sert de voiture de test. Le spawner n'a besoin de rien de spécial ici :
## il observe juste la position image par image, donc il fonctionnera pareil
## avec votre propre système de mouvement plus tard.

@export var speed: float = 400.0
@export var rotation_speed: float = 4.0

func _process(delta: float) -> void:
	rotation += Input.get_axis("ui_left", "ui_right") * rotation_speed * delta
	var throttle := Input.get_axis("ui_down", "ui_up")
	position += Vector2.UP.rotated(rotation) * throttle * speed * delta
