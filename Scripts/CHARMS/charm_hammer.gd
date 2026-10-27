extends CharmEffect
## Hammer: a wall hit no longer breaks the drift nor the combo

func activate(_p_charm : CharmData) -> void:
	CarManager.selected_car.wall_keeps_drift = true

func deactivate() -> void:
	CarManager.selected_car.wall_keeps_drift = false
