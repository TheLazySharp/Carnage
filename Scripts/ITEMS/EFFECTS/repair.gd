extends ItemEffect

func activate() -> void:
	ItemManager.emit_signal("repair",0.25)

func deactivate() -> void:
	pass
