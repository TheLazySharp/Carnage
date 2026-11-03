extends CharmEffect
## Rabbit foot: p_value chance (0-1) that a maneuver salvo fires a second time


func activate(p_charm : CharmData) -> void:
	CarManager.selected_car.salvo_repeat_chance = p_charm.p_value

func deactivate() -> void:
	CarManager.selected_car.salvo_repeat_chance = 0.0
