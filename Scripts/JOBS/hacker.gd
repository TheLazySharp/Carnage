extends JobEffect
## Hacker: the first shop reroll after each raid is free


func activate() -> void:
	ShopManager.free_rerolls_per_visit += 1
	ShopManager.free_rerolls_left += 1


func deactivate() -> void:
	ShopManager.free_rerolls_per_visit -= 1
	ShopManager.free_rerolls_left = mini(ShopManager.free_rerolls_left, ShopManager.free_rerolls_per_visit)
