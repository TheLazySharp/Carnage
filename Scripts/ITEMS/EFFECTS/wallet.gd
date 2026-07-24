extends ItemEffect

func activate() -> void:
	ItemManager.emit_signal("wallet")
	

func deactivate() -> void:
	pass
