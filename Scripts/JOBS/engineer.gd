extends JobEffect


func activate() -> void:
	SignalManager.next_day.connect(_on_next_day)

func deactivate() -> void:
	SignalManager.next_day.disconnect(_on_next_day)

func _on_next_day() -> void : 
	XPManager.available_upgrades += 1
