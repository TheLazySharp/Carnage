extends ItemEffect

func activate() -> void:
	ItemManager.emit_signal("repair",50)

func deactivate() -> void:
	pass
