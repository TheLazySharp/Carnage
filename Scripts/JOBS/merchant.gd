extends JobEffect

var discount : float = - 0.2
var merchant_mod : Modifier

func activate() -> void:
	ShopManager.apply_discount =  true
	merchant_mod = Modifier.new(discount,Modifier.Type.PERCENT_MULT,"merchant discount")
	ShopManager.discount.add_modifier(merchant_mod)


func deactivate() -> void:
	ShopManager.apply_discount =  false
	ShopManager.discount.remove_modifier(merchant_mod)
