extends Node

var max_life: int = 100
var speed: int = 250
var collect_radius: float


func _process(_delta: float) -> void:
	if Input.is_action_just_released("tests"):
		max_life +=1
		print("max health +1 : ",max_life)
