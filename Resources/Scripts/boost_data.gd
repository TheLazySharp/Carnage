extends Resource
class_name BoostData

enum Target_Ressources {
	N_A,
	CAR,
	WEAPONS,
	AMMOS,
}

enum Target_Stats {
	N_A,
	WEAPON_DMG,
	FIRE_RATE,
	NB_AMMO,
	RANGE,
	RADIUS,
	COOL_DOWN,
	SPEED,
	SPEED_ROTATION,
	ACCELERATION,
	MAX_SPEED,
	MAX_LIFE,
	CAR_DMG,
	DASH_DMG_BONUS,
	DASH_DURATION,
	NITRO_UP,
	COLLECT_RADIUS,
	DRIFT_TURN_BONUS,
	MAX_FUEL,
	MAX_NITRO
}

enum Mod_Type {
	FLAT,
	PERCENT_ADD,
	PERCENT_MULT,
}

enum Rarities {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY
}

@export var name : ShopManager.Items_Name
@export var target_ressource : Target_Ressources
@export var target_weapon : WeaponData
@export var target_stats : Array[Target_Stats]
@export var target_stats_values : Array[float]
@export var target_stats_modifier_types : Array[Mod_Type]
@export var target_weapon_types : WeaponsManager.Type
@export var icon : Texture2D
@export var text : String
@export var rarity : Rarities
#var price : int
#var is_in_shop : bool = false

func get_stats()-> Array[Dictionary]:
	var stats: Array[Dictionary] = []
	match target_ressource:
		Target_Ressources.CAR:
			for i in target_stats.size():
				var stat : Statistic = get_car_stat(target_stats[i],CarManager.selected_car)
				if stat : 
					stats.append({
						"stat":stat,
						"value":target_stats_values[i],
						"type":target_stats_modifier_types[i]
					})
		
		Target_Ressources.WEAPONS:
			if !target_weapon:
				if target_weapon_types != WeaponsManager.Type.N_A:
					for weapon : WeaponData in WeaponsManager.WEAPONS_TYPES[target_weapon_types].size():
						for i in target_stats.size():
							var stat : Statistic = get_weapon_stat(target_stats[i],weapon)
							if stat :
								stats.append({
									"stat":stat,
									"value":target_stats_values[i],
									"type":target_stats_modifier_types[i]
								})
				else : pass
			else :
				for i in target_stats.size():
					var stat : Statistic = get_weapon_stat(target_stats[i],target_weapon)
					if stat :
						stats.append({
							"stat":stat,
							"value":target_stats_values[i],
							"type":target_stats_modifier_types[i]
						})
		
		Target_Ressources.AMMOS:
			if !target_weapon:
				if target_weapon_types != WeaponsManager.Type.N_A:
					for weapon : WeaponData in WeaponsManager.WEAPONS_TYPES[target_weapon_types].size():
						for i in target_stats.size():
							var stat : Statistic = get_weapon_stat(target_stats[i],weapon.weapon_ammo_res)
							if stat :
								stats.append({
									"stat":stat,
									"value":target_stats_values[i],
									"type":target_stats_modifier_types[i]
								})
				else : pass
			else :
				for i in target_stats.size():
					var stat : Statistic = get_weapon_stat(target_stats[i],target_weapon.weapon_ammo_res)
					if stat :
						stats.append({
							"stat":stat,
							"value":target_stats_values[i],
							"type":target_stats_modifier_types[i]
						})
	return stats

func get_shop_color() -> Color:
	return ShopManager.item_colors[rarity]

func get_shop_weight() -> float:
	return ShopManager.item_levels[rarity]

func get_stat_string(stat : Target_Stats) -> String:
	match stat:
		Target_Stats.N_A: return ""
		Target_Stats.ACCELERATION: return "Acceleration"
		Target_Stats.MAX_SPEED: return "Max Speed"
		Target_Stats.MAX_LIFE: return "Max Life"
		Target_Stats.MAX_FUEL: return "Max Fuel"
		Target_Stats.MAX_NITRO: return "Max Nitro"
		Target_Stats.CAR_DMG: return "Car Damages"
		Target_Stats.DASH_DMG_BONUS: return "Dash Damages"
		Target_Stats.DASH_DURATION: return "Dash Duration"
		Target_Stats.NITRO_UP: return "Nitro gain"
		Target_Stats.COLLECT_RADIUS: return "Collect Radius"
		Target_Stats.DRIFT_TURN_BONUS: return "Drift Turn"
		Target_Stats.WEAPON_DMG: return "Weapon Damages"
		Target_Stats.FIRE_RATE: return "Fire Rate"
		Target_Stats.NB_AMMO: return "Nb Ammo"
		Target_Stats.RANGE: return "Range"
		Target_Stats.RADIUS: return "Radius"
		Target_Stats.COOL_DOWN: return "Cool Down"
		Target_Stats.SPEED: return "Speed"
		Target_Stats.SPEED_ROTATION: return "Speed Rotation"
	return ""

func get_rarity_string(boost_rarity : Rarities) -> String:
	match boost_rarity:
		Rarities.COMMON: return "Common"
		Rarities.RARE: return "Rare"
		Rarities.EPIC: return "Epic"
		Rarities.LEGENDARY: return "Legendary"
	return ""

func get_car_stat(target_stat : Target_Stats, car : CarData) -> Statistic:
	match target_stat:
		Target_Stats.ACCELERATION: return car.acceleration
		Target_Stats.MAX_SPEED: return car.max_speed
		Target_Stats.MAX_LIFE: return car.max_life
		Target_Stats.MAX_FUEL: return car.max_fuel
		Target_Stats.COLLECT_RADIUS: return car.collect_radius
		Target_Stats.DASH_DMG_BONUS: return car.dash_dmg_bonus
		Target_Stats.DASH_DURATION: return car.dash_duration
		Target_Stats.NITRO_UP: return car.nitro_up
		Target_Stats.DRIFT_TURN_BONUS: return car.drift_turn_bonus
		Target_Stats.CAR_DMG: return car.dmg
		Target_Stats.MAX_NITRO: return car.max_nitro
	return null

func get_weapon_stat(target_stat : Target_Stats, weapon : WeaponData) -> Statistic:
	match target_stat:
		Target_Stats.WEAPON_DMG: return weapon.dmg
		Target_Stats.SPEED: return weapon.speed
		Target_Stats.SPEED_ROTATION: return weapon.speed_rotation
		Target_Stats.RADIUS: return weapon.radius
		Target_Stats.RANGE: return weapon.atk_range
		Target_Stats.FIRE_RATE: return weapon.fire_rate
		Target_Stats.COOL_DOWN: return weapon.cool_down
		Target_Stats.NB_AMMO: return weapon.nb_ammo
	return null

func get_modifier_type(mod_type : Mod_Type) -> Modifier.Type :
	match mod_type:
		Mod_Type.FLAT: return Modifier.Type.FLAT
		Mod_Type.PERCENT_ADD: return Modifier.Type.PERCENT_ADD
		Mod_Type.PERCENT_MULT: return Modifier.Type.PERCENT_MULT
	return Modifier.Type.N_A
