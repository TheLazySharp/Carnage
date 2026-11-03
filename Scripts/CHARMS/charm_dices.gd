extends CharmEffect
## Fuzzy dice: p_value chance (0-1) that a maneuver is amplified for free, as if the car was dashing

func activate(p_charm : CharmData) -> void:
	CarManager.selected_car.free_amplify_chance = p_charm.p_value

func deactivate() -> void:
	CarManager.selected_car.free_amplify_chance = 0.0
