extends Resource
class_name LuckyCharmData

@export var name: String
@export var icon: Texture2D
@export var description: String

@export_category("Car Boost")
@export var life_bonus : float #increase car life in %
@export var max_speed_bonus : float #increase car max speed in %
@export var acceleration_bonus : float #increase car acceleration in %
@export var damages_bonus : float #increase car damages in %
@export var dash_damages_bonus : float #increase car damages when dashing in %
@export var nitro_bonus : float #increase length of the dash in %
@export var tires_bonus : float #increase effectivness of drift to fill up the dash gauge in %
@export var magnetism_bonus : float #increase the size of the zone where XP are collected by the car

@export_category("Weapon Boost")
@export var short_range_dmg_bonus : float # increase damages of short range weapons in %
@export var short_range_fire_rate_bonus : float # increase fire rate of short range weapons in %

@export var long_range_dmg_bonus : float # increase damages of long range weapons in %
@export var long_range_fire_rate_bonus : float # increase fire rate of long range weapons in %


@export var automatic_dmg_bonus : float # increase damages of automatic weapons in %
@export var automatic_fire_rate_bonus : float # increase fire rate of automatic weapons in %
# ADD EXTRA AMMO

@export var non_automatic_dmg_bonus : float # increase damages of non-automatic weapons in %
@export var non_automatic_fire_rate_bonus : float # increase fire rate of non-automatic weapons in %

@export var explosives_range_bonus : float # increase radius of explosions in %
@export var explosives_dmg_bonus : float # increase dmg of explosions in %
@export var explosives_fire_rate_bonus : float # increase fire_rate of explosions in %

@export var elemental_dmg_bonus : float # increase damages of elemental weapons in %
@export var elemental_fire_rate_bonus : float # increase fire rate of elemental weapons in %
@export var elemental_range_bonus : float # increase radius of elemental weapons in %

@export var all_dmg_bonus : float # increase damages of all weapons in %
@export var all_fire_rate_bonus : float # increase fire rate of all weapons in %
@export var all_range_bonus : float # increase radius of all weapons in %
