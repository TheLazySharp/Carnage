extends CharmEffect
## Rear bumper mastery: the enemy thrown by a perfect hit crosses every enemy until a wall


func activate(_p_charm : CharmData) -> void:
	CarManager.selected_car.rocket_enabled = true


func deactivate() -> void:
	CarManager.selected_car.rocket_enabled = false
