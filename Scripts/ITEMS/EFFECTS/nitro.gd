extends ItemEffect

var nitro_added : float = 50

func activate() -> void:
	ItemManager.emit_signal("nitro_up", nitro_added)
	

func deactivate() -> void:
	pass
