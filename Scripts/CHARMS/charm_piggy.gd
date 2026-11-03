extends CharmEffect
## Piggy bank: p_value of the harvested blood goes to the shop wallet instead of the car


func activate(p_charm : CharmData) -> void:
	CarManager.selected_car.blood_to_bank_ratio = p_charm.p_value


func deactivate() -> void:
	CarManager.selected_car.blood_to_bank_ratio = 0.0
