extends JobEffect
# Transporter: one more projectile on every weapon (up to its max_projectile)

var transporter_mod : Modifier = Modifier.new(job.p_value, Modifier.Type.FLAT, "transporter job")


func activate() -> void:
	if !SignalManager.weapon_stats_initiated.is_connected(_on_weapon_stats_initiated):
		SignalManager.weapon_stats_initiated.connect(_on_weapon_stats_initiated)
	for weapon : WeaponData in WeaponsManager.weapons:
		_apply(weapon)


func deactivate() -> void:
	if SignalManager.weapon_stats_initiated.is_connected(_on_weapon_stats_initiated):
		SignalManager.weapon_stats_initiated.disconnect(_on_weapon_stats_initiated)
	for weapon : WeaponData in WeaponsManager.weapons:
		weapon.nb_projectile.remove_modifier(transporter_mod)


func _on_weapon_stats_initiated(p_weapon : WeaponData) -> void:
	if WeaponsManager.weapons.has(p_weapon):
		_apply(p_weapon)


func _apply(weapon : WeaponData) -> void:
	if weapon.nb_projectile.modifiers.has(transporter_mod):
		return
	if weapon.nb_projectile.get_value() < weapon.max_projectile:
		weapon.nb_projectile.add_modifier(transporter_mod)
