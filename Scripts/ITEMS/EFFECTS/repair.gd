extends ItemEffect

func activate() -> void:
	ItemManager.emit_signal("repair",20)

func deactivate() -> void:
	pass
