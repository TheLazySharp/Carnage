extends JobEffect

var hunter_mod : Modifier = Modifier.new(0.5,Modifier.Type.PERCENT_MULT,"hunter job")
var applied : bool = false

func activate() -> void:
	if CarManager.selected_car == null and !applied:
		CarManager.car_selected.connect(_on_car_selected)
		return
	CarManager.selected_car.collect_radius.add_modifier(hunter_mod)
	applied = true


func deactivate() -> void:
	CarManager.selected_car.collect_radius.remove_modifier(hunter_mod)


func _on_car_selected() -> void :
	print("hunter : stats car initiated")
	if !applied:
		CarManager.selected_car.collect_radius.add_modifier(hunter_mod)
		applied = true
		print("hunter : applied : ",CarManager.selected_car.collect_radius.get_value())
		
	
