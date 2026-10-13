extends Node
class_name State

@warning_ignore("unused_signal")
signal state_changed
## Enemies (itself included) needed in the 3x3 cells around this enemy to join a horde mass while in this state.
## -1 = HordeOutline.min_cluster_count, 0 = never joins a mass (its own animation stays visible).
@export var mass_cluster_count: int = -1

func enter()-> void:
	pass

func exit()-> void:
	pass

func update(_delta: float)-> void:
	pass

func physics_update(_delta: float)-> void:
	pass
