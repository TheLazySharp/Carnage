class_name BloodShotPool
extends Node2D

@export var blood_shot_scene: PackedScene
@export var pool_size: int = 100

var shots: Array[CPUParticles2D] = []
var write_cursor: int = 0


func _ready() -> void:
	shots.resize(pool_size)
	for i: int in range(pool_size):
		var shot: CPUParticles2D = blood_shot_scene.instantiate() as CPUParticles2D
		add_child(shot)
		shot.emitting = false
		shots[i] = shot


func shoot_blood(shot_position: Vector2, shot_rotation: float) -> void:
	var shot: CPUParticles2D = shots[write_cursor]
	write_cursor = (write_cursor + 1) % pool_size
	shot.global_position = shot_position
	shot.global_rotation = shot_rotation
	shot.restart()
