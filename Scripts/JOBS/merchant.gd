extends JobEffect
## Merchant: -20% on every shop price (stacks with the hawaiian charm)

const DISCOUNT : float = -0.2
var merchant_mod : Modifier = null


func activate() -> void:
	if merchant_mod != null:
		return 
	merchant_mod = Modifier.new(DISCOUNT, Modifier.Type.PERCENT_MULT, "merchant discount")
	ShopManager.discount.add_modifier(merchant_mod)
	ShopManager.apply_discount = ShopManager.discount.get_value() < 1.0


func deactivate() -> void:
	if merchant_mod == null:
		return
	ShopManager.discount.remove_modifier(merchant_mod)
	merchant_mod = null
	ShopManager.apply_discount = ShopManager.discount.get_value() < 1.0
