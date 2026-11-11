extends JobEffect
#Collectionist: one more charm slot on the car.

var collectionist_mod : Modifier = Modifier.new(job.p_value, Modifier.Type.FLAT, "collectionist job")
var applied_stat : Statistic = null


func activate() -> void:
	if !CarManager.car_selected.is_connected(_on_car_selected):
		CarManager.car_selected.connect(_on_car_selected)
	_apply_to_selected_car()


func deactivate() -> void:
	if CarManager.car_selected.is_connected(_on_car_selected):
		CarManager.car_selected.disconnect(_on_car_selected)
	_remove()
	if CarManager.selected_car != null:
		CharmsManager.fit_to_slots()


func _on_car_selected() -> void:
	_apply_to_selected_car()


func _apply_to_selected_car() -> void:
	if CarManager.selected_car == null or CarManager.selected_car.charm_slots == null:
		return
	var target_stat : Statistic = CarManager.selected_car.charm_slots
	if target_stat == applied_stat:
		return
	_remove()
	target_stat.add_modifier(collectionist_mod)
	applied_stat = target_stat


func _remove() -> void:
	if applied_stat == null:
		return
	applied_stat.remove_modifier(collectionist_mod)
	applied_stat = null
