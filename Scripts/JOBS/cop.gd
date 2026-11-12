extends JobEffect
## Cop (arrest): enemies caught in a projected enemy burst (perfect hit, ram) are frozen for p_value seconds

func activate() -> void:
	CarManager.selected_car.drift_hit_freeze_duration = job.p_value

func deactivate() -> void:
	CarManager.selected_car.drift_hit_freeze_duration = 0.0
