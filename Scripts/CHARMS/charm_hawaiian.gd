extends CharmEffect
## Hawaiian shirt: -10% on every shop price (stacks with the merchant job)

const DISCOUNT : float = -0.1
var charm_mod : Modifier = null


func activate(_p_charm : CharmData) -> void:
	if charm_mod != null:
		return
	charm_mod = Modifier.new(DISCOUNT, Modifier.Type.PERCENT_MULT, "charm shop discount")
	ShopManager.discount.add_modifier(charm_mod)
	ShopManager.apply_discount = ShopManager.discount.get_value() < 1.0


func deactivate() -> void:
	if charm_mod == null:
		return
	ShopManager.discount.remove_modifier(charm_mod)
	charm_mod = null
	ShopManager.apply_discount = ShopManager.discount.get_value() < 1.0
