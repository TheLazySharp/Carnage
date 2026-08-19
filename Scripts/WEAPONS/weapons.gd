extends Node2D


func _ready() -> void:
	if owner != null and owner.get("debug_drive_mode") == true:
		return
	WeaponsManager.instantiate_weapons()
	if GameMaster.game_mode == GameMaster.GAME_MODES.GOD:
		WeaponsManager.god_mod_full_power()
