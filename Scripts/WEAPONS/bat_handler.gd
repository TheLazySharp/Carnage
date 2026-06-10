extends Node2D

@export var handler_data : WeaponData
@onready var player: CharacterBody2D = $/root/World/Car

var car : CarData
const BASEBALL_BAT = preload("uid://c5g74aadec237")
var car_height : float
var spawn_pos_angles  : Array[float] = []


func _ready() -> void:
	car = CarManager.selected_car
	car_height = car.car_sprite.get_height()
	spawn_baseballbat(player.rotation)
	spawn_pos_angles = [
		PI/2,
		-PI/2,
		0.0,
		PI,
		PI/4,
		-PI/4,
		3 * PI/4,
		-3 * PI/4
	]

func _process(_delta: float) -> void:
	if int(handler_data.nb_projectile.get_value()) == get_child_count(false):
		return
	spawn_baseballbat(player.rotation)


func spawn_baseballbat(car_rotation : float,p_nb_projectile : int = int(handler_data.nb_projectile.get_value()), origin : Vector2 = player.global_position) -> void : 
	if get_child_count(false) > 0:
		for i in get_children().size():
			get_children()[i].queue_free()
	
	for i in range(min(p_nb_projectile,spawn_pos_angles.size())):
		var angle : float = spawn_pos_angles[i] + car_rotation
		var offset : Vector2 = Vector2.RIGHT.rotated(angle) * car_height
		var bat : Node2D = BASEBALL_BAT.instantiate()
		add_child(bat)
		bat.global_position = origin + offset
		bat.rotation = spawn_pos_angles[i] - PI/2
