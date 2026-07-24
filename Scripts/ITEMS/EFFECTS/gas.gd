extends ItemEffect

func activate() -> void:
	ItemManager.emit_signal("gas")

func deactivate() -> void:
	pass
