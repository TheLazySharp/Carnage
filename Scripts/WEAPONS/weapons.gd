extends Node2D


func _ready() -> void:
	WeaponsManager.reinit_weapons()
	#WeaponsManager.check_weapons()
