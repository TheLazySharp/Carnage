extends Control


@onready var car_neons : CarNeons = get_tree().get_first_node_in_group(&"car_neons") as CarNeons
var neons_call_threshold : float = 0.15




func _on_car_blood_changed(current_life : int, max_life : int) -> void:
	if current_life < max_life * neons_call_threshold:
		car_neons.play(&"low_health", Color(1.0, 0.05, 0.02, 1.0), CarNeons.Pattern.BLINK, CarNeons.HOLD_UNTIL_STOP, CarNeons.PRIORITY_LOW_HEALTH, 0.3)
	if current_life >= max_life * neons_call_threshold:
		car_neons.stop(&"low_health")
