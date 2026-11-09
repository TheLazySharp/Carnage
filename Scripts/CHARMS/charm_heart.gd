extends CharmEffect
## Blood tank mastery: once per run, the driver comes back instead of dying.


func activate(p_charm : CharmData) -> void:
	CarManager.selected_car.second_life_enabled = true
	CarManager.selected_car.second_life_ratio = p_charm.p_value


func deactivate() -> void:
	CarManager.selected_car.second_life_enabled = false
