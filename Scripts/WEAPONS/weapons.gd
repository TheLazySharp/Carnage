extends Node2D


func _ready() -> void:
	WeaponsManager.instantiate_weapons()
	print("weapons ready")
	#WeaponsManager.check_weapons()
