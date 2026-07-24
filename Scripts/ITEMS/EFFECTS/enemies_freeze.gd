extends ItemEffect

func activate() -> void:
	ItemManager.emit_signal("freeze")

func deactivate() -> void:
	pass
