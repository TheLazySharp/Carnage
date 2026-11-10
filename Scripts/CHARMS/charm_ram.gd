extends CharmEffect
## Front bumper mastery: an enemy hit head-on at speed is thrown ahead like a classic perfect hit


func activate(_p_charm : CharmData) -> void:
	CarManager.selected_car.ram_enabled = true


func deactivate() -> void:
	CarManager.selected_car.ram_enabled = false
