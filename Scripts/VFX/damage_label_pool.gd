class_name DamageLabelPool
extends Node2D

# RING BUFFER

@export var label_scene : PackedScene
@export var pool_size: int = 1000
var label_pool : Array[Damage_label] = []
var write_cursor : int = 0


func _ready() -> void:
	label_pool.resize(pool_size)
	for i : int in range(pool_size):
		label_pool[i] = add_new_label()


func show_damages(damage_value : int, pos : Vector2) -> void :
	var new_label : Damage_label = _get_label_from_pool()
	new_label.display_damages(damage_value, pos)


## Ring buffer: no scan at all. Under overload the oldest label is recycled,
## which is why display_damages kills the previous tween.
func _get_label_from_pool() -> Damage_label :
	var label : Damage_label = label_pool[write_cursor]
	write_cursor = (write_cursor + 1) % pool_size
	return label


func add_new_label() -> Damage_label :
	var label : Damage_label = label_scene.instantiate()
	label.hide()
	add_child(label)
	return label
