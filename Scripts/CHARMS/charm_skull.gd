extends CharmEffect
## Skull: while the survivor life is under p_value of its max, every weapon deals more damages

const SKULL_SOURCE : String = "CHARM_SKULL_MOD"

var skull_modifier : Modifier
var is_boosted : bool = false  # the modifier is on the weapons: never added twice


func activate(p_charm : CharmData) -> void:
	skull_modifier = Modifier.new(CharmsManager.charm_skull_dmg_boost, Modifier.Type.PERCENT_ADD, SKULL_SOURCE)
	SignalManager.charm_skull_triggered.connect(_on_charm_skull_triggered)
	CharmsManager.charm_skull_life_floor = p_charm.p_value


func deactivate() -> void:
	CharmsManager.charm_skull_life_floor = 0.0
	if SignalManager.charm_skull_triggered.is_connected(_on_charm_skull_triggered):
		SignalManager.charm_skull_triggered.disconnect(_on_charm_skull_triggered)
	remove_skull_mod()


func _on_charm_skull_triggered(skull_triggered : bool) -> void:
	if skull_triggered:
		apply_skull_mod()
	else:
		remove_skull_mod()


func apply_skull_mod() -> void:
	if is_boosted:
		return
	is_boosted = true
	for weapon : WeaponData in WeaponsManager.weapons:
		weapon.weapon_ammo_res.dmg.add_modifier(skull_modifier)
	SignalManager.charm_triggered.emit(ShopManager.CONST_REFS.Charm_Skull)


func remove_skull_mod() -> void:
	if !is_boosted:
		return
	is_boosted = false
	for weapon : WeaponData in WeaponsManager.weapons:
		weapon.weapon_ammo_res.dmg.remove_modifier(skull_modifier)
