extends CharmEffect
## Bullet: p_value more projectiles on every weapon (up to its max_projectile)

var charm_projectile_mod : Modifier = null


func activate(p_charm : CharmData) -> void:
	if charm_projectile_mod != null:
		return   # already active: never added twice
	charm_projectile_mod = Modifier.new(float(int(p_charm.p_value)), Modifier.Type.FLAT, "add projectile from charm")
	if !SignalManager.weapon_stats_initiated.is_connected(_on_weapon_stats_initiated):
		SignalManager.weapon_stats_initiated.connect(_on_weapon_stats_initiated)
	for weapon : WeaponData in WeaponsManager.weapons:
		_apply(weapon)


func deactivate() -> void:
	if SignalManager.weapon_stats_initiated.is_connected(_on_weapon_stats_initiated):
		SignalManager.weapon_stats_initiated.disconnect(_on_weapon_stats_initiated)
	if charm_projectile_mod == null:
		return
	for weapon : WeaponData in WeaponsManager.weapons:
		weapon.nb_projectile.remove_modifier(charm_projectile_mod)
	charm_projectile_mod = null


func _on_weapon_stats_initiated(p_weapon : WeaponData) -> void:
	if WeaponsManager.weapons.has(p_weapon):
		_apply(p_weapon)


func _apply(weapon : WeaponData) -> void:
	if weapon.nb_projectile.modifiers.has(charm_projectile_mod):
		return
	if weapon.nb_projectile.get_value() < weapon.max_projectile:
		weapon.nb_projectile.add_modifier(charm_projectile_mod)
