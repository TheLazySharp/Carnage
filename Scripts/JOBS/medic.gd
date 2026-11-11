extends JobEffect
## Medic: the driver back to full life at each shop visit (after each raid). Healing to max: no extra gain on a second visit


func activate() -> void:
	SignalManager.shop_entered.connect(_on_shop_entered)


func deactivate() -> void:
	if SignalManager.shop_entered.is_connected(_on_shop_entered):
		SignalManager.shop_entered.disconnect(_on_shop_entered)


func _on_shop_entered() -> void:
	var driver : SurvivorData = SurvivorsManager.on_board_survivors[0]
	driver.current_life = driver.max_life
	BloodBars.update_survivor_blood()
