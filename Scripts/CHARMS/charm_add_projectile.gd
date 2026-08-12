extends CharmEffect

# ADD TO CHARMDATA TO CONST " ALL_CHARMS" IN SHOP_MANAGER.GD

var charm_projectile_mod : Modifier = Modifier.new(1,Modifier.Type.FLAT,"add projectile from charm")
var nb : int

func activate(p_charm : CharmData) -> void:
	SignalManager.weapon_stats_initiated.connect(_on_weapon_stats_initiated)
	nb = CharmsManager.nb_projectile_added[p_charm.rarity]
	charm_projectile_mod = Modifier.new(nb,Modifier.Type.FLAT,"add projectile from charm")
	
	if !WeaponsManager.weapons.is_empty():
		for i in WeaponsManager.weapons.size():
			if WeaponsManager.weapons[i].nb_projectile.get_value() < WeaponsManager.weapons[i].max_projectile:
				WeaponsManager.weapons[i].nb_projectile.add_modifier(charm_projectile_mod)

func deactivate() -> void:
	pass


func apply_charm(p_weapon : WeaponData) -> void : 
	if WeaponsManager.weapons.has(p_weapon):
		for i in WeaponsManager.weapons.size():
			if WeaponsManager.weapons[i] == p_weapon and WeaponsManager.weapons[i].nb_projectile.get_value() < WeaponsManager.weapons[i].max_projectile:
				WeaponsManager.weapons[i].nb_projectile.add_modifier(charm_projectile_mod)
	

func fired_job() -> void : 
	for i in WeaponsManager.weapons.size():
		WeaponsManager.weapons[i].nb_projectile.remove_modifier(charm_projectile_mod)


func _on_weapon_stats_initiated(p_weapon : WeaponData) -> void :
	apply_charm(p_weapon)
