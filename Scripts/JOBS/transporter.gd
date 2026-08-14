extends JobEffect

var transporter_mod : Modifier = Modifier.new(1,Modifier.Type.FLAT,"transporter job")


func activate() -> void:
	SignalManager.weapon_stats_initiated.connect(_on_weapon_stats_initiated)
	if !WeaponsManager.weapons.is_empty():
		for i in WeaponsManager.weapons.size():
			if WeaponsManager.weapons[i].nb_projectile.get_value() < WeaponsManager.weapons[i].max_projectile:
				WeaponsManager.weapons[i].nb_projectile.add_modifier(transporter_mod)


func deactivate() -> void:
	fired_job()

func apply_transporter_job(p_weapon : WeaponData) -> void : 
	if WeaponsManager.weapons.has(p_weapon):
		for i in WeaponsManager.weapons.size():
			if WeaponsManager.weapons[i] == p_weapon and WeaponsManager.weapons[i].nb_projectile.get_value() < WeaponsManager.weapons[i].max_projectile:
				WeaponsManager.weapons[i].nb_projectile.add_modifier(transporter_mod)
	

func fired_job() -> void : 
	for i in WeaponsManager.weapons.size():
		WeaponsManager.weapons[i].nb_projectile.remove_modifier(transporter_mod)


func _on_weapon_stats_initiated(p_weapon : WeaponData) -> void :
	apply_transporter_job(p_weapon)
