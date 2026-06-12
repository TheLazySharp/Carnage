extends Node2D

@export var flamer_data : WeaponData
const FLAME = preload("uid://baidslgub6j8k")

@onready var car : CharacterBody2D = $"/root/World/Car"

func _ready() -> void:
	flamer_data.nb_projectile.stat_adjusted.connect(_on_nb_projectile_changed)
	spawn_flame(car.rotation)


func spawn_flame(car_rotation : float, p_nb_projectile : int = int(flamer_data.nb_projectile.get_value()), origin : Vector2 = self.global_position) -> void : 
	if get_child_count(false) > 0:
		for i in get_children().size():
			get_children()[i].queue_free()
	var arc_radius : float = 30
	var angle_step : float = 30
	var start_angle : float = -((p_nb_projectile - 1) * angle_step) * .5

	for i in range(p_nb_projectile):
		var angle : float = car_rotation + deg_to_rad(start_angle + i * angle_step)
		var offset : Vector2 = Vector2.RIGHT.rotated(angle) * arc_radius
		var flame : Area2D = FLAME.instantiate()
		add_child(flame)
		flame.global_position = origin + offset
		flame.global_rotation = angle

func _on_nb_projectile_changed(_final_value : float) -> void : 
	spawn_flame(car.rotation)
