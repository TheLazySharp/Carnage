extends CharmEffect
## Syringe: every maneuver is amplified while the driver blood is under p_value of its max


func activate(p_charm : CharmData) -> void:
	CarManager.selected_car.low_blood_amplify_ratio = p_charm.p_value


func deactivate() -> void:
	CarManager.selected_car.low_blood_amplify_ratio = 0.0
