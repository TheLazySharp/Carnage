class_name EnemySpriteState
extends Resource

## Nom de l'état (ex: "walk", "attack", "death")
@export var state_name: String = "walk"

## Indice de la ligne dans la spritesheet (0 = première ligne)
@export var sheet_row: int = 0

## Nombre de frames pour cet état
@export var frame_count: int = 11

## Vitesse de l'animation en frames par seconde
@export var fps: float = 10.0

## Est-ce que l'animation boucle ?
@export var loop: bool = true
