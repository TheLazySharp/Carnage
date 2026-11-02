extends JobEffect
# Mechanic: gives back up to 20% of the car max life when arriving at the shop

const REPAIR_RATIO : float = 0.2


func activate() -> void:
	if !SignalManager.shop_entered.is_connected(_on_shop_entered):
		SignalManager.shop_entered.connect(_on_shop_entered)


func deactivate() -> void:
	if SignalManager.shop_entered.is_connected(_on_shop_entered):
		SignalManager.shop_entered.disconnect(_on_shop_entered)


func _on_shop_entered() -> void:
	var car : CarData = CarManager.selected_car
	var max_life : int = int(car.max_life.get_value())
	var repair : int = roundi(max_life * REPAIR_RATIO)
	car.current_life = mini(car.current_life + repair, max_life)
	BloodBars.update_car_blood()
