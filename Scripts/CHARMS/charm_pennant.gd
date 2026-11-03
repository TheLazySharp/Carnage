extends CharmEffect
# Club pennant: repeating the same maneuver still raises the combo, with p_value of the normal gain

func activate(p_charm : CharmData) -> void:
	CarManager.selected_car.combo_repeat_gain = p_charm.p_value

func deactivate() -> void:
	CarManager.selected_car.combo_repeat_gain = 0.0
