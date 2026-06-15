class_name DamageLabelPool
extends Node2D

@export var label_scene : PackedScene
@export var pool_size: int = 400
var label_pool : Array[Label] = []


func _ready() -> void:
	for i in range(pool_size):
		add_new_label()


func show_damages(damage_value : int, pos : Vector2) -> void : 
	var new_label : Damage_label = _get_label_from_pool()
	new_label.display_damages(damage_value,pos)
	
func _get_label_from_pool() -> Damage_label : 
	for label : Damage_label in label_pool:
		if !label.in_use :
			return label
	push_warning("DamageLabelPool grown to %d" % (label_pool.size() + 1))
	return add_new_label()

func add_new_label() -> Damage_label : 
	var label  : Damage_label = label_scene.instantiate()
	label.hide()
	add_child(label)
	label_pool.append(label)
	return label
