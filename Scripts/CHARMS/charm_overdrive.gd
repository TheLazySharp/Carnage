extends CharmEffect
## Engine mastery: while dashing, the targeted enemy types die in one hit and never slow the car down


func activate(_p_charm : CharmData) -> void:
	CarManager.selected_car.overdrive_enabled = true


func deactivate() -> void:
	CarManager.selected_car.overdrive_enabled = false
