extends ItemEffect

func activate() -> void:
	ItemManager.emit_signal("magnet_xp")

func deactivate() -> void:
	pass
