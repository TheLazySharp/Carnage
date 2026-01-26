extends Label


func _process(_delta: float) -> void:
	text = "LEVEL " + str(XPManager.current_level)
