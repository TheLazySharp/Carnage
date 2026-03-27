extends Label


func _process(_delta: float) -> void:
	if self.visible :
		text = "LEVEL " + str(XPManager.current_level)
