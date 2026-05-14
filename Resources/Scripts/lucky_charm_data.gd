extends Resource
class_name LuckyCharmData


# EVERY NEW LUCKY CHARMS HAS TO BE INIT IN THE LUCKYCHARMMANAGER SCRIPT IN THE INIT() FUNCTION

@export var name: String
@export var icon: Texture2D
@export var description: String

enum Target_Ressources {
	N_A,
	CAR,
	WEAPONS,
	AMMOS,
}


@export var target_ressource : Target_Ressources
@export var weapon_type : WeaponsManager.Type
@export var target_weapon_stat : WeaponData.Stats_Types
@export var target_car_stat : CarData.Car_Stats
@export var modifier_value : float
@export var modifier_type : Modifier.Type
