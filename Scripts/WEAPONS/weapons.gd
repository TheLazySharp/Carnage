extends Node2D


func _ready() -> void:
	if GameMaster.is_debug():
		return
	WeaponsManager.instantiate_weapons()
	if GameMaster.game_mode == GameMaster.GAME_MODES.GOD:
		WeaponsManager.god_mod_full_power()
