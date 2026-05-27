extends CharmEffect

# ADD TO CONST " ALL_CHARMS" IN SHOP_MANAGER.GD

const DURATION = 100000.0

func activate() -> void:
	CarManager.selected_car.invincible = true
	await Engine.get_main_loop().create_timer(DURATION).timeout
	deactivate()

func deactivate() -> void:
	CarManager.selected_car.invincible = false
