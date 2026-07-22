extends CharmEffect

var discount : float = - 0.1
var charm_mod : Modifier


func activate(_p_charm : CharmData) -> void:
	ShopManager.apply_discount =  true
	charm_mod = Modifier.new(discount,Modifier.Type.PERCENT_MULT,"charm shop discount")
	ShopManager.discount.add_modifier(charm_mod)

func deactivate() -> void:
	ShopManager.apply_discount =  false
	ShopManager.discount.remove_modifier(charm_mod)
