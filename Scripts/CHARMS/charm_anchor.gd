extends CharmEffect
## Anchor: the combo never decays below p_value (x2), and each raid starts there


func activate(p_charm : CharmData) -> void:
	CarManager.selected_car.combo_floor = maxf(p_charm.p_value, 1.0)


func deactivate() -> void:
	CarManager.selected_car.combo_floor = 1.0
