extends JobEffect
# Hunter: +50% collect radius on the car.

var hunter_mod : Modifier = Modifier.new(0.5, Modifier.Type.PERCENT_MULT, "hunter job")
var applied_stat : Statistic = null


func activate() -> void:
	if !CarManager.car_selected.is_connected(_on_car_selected):
		CarManager.car_selected.connect(_on_car_selected)
	_apply_to_selected_car()


func deactivate() -> void:
	if CarManager.car_selected.is_connected(_on_car_selected):
		CarManager.car_selected.disconnect(_on_car_selected)
	_remove()


func _on_car_selected() -> void:
	_apply_to_selected_car()


func _apply_to_selected_car() -> void:
	if CarManager.selected_car == null or CarManager.selected_car.collect_radius == null:
		return
	var target_stat : Statistic = CarManager.selected_car.collect_radius
	if target_stat == applied_stat:
		return
	_remove()
	target_stat.add_modifier(hunter_mod)
	applied_stat = target_stat


func _remove() -> void:
	if applied_stat == null:
		return
	applied_stat.remove_modifier(hunter_mod)
	applied_stat = null
