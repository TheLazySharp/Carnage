extends Resource
class_name ItemData

@export_category("General")
@export var name: String
@export var icon: Texture2D
@export var description: String
@export var effect_script : GDScript

@export_category("If Reward")

enum REWARD_TYPES {
	N_A,
	CAR_UPGRADE,
	WEAPON_UPGRADE,
	AMMO_UPGRADE,
	CHARM
}

@export var reward_type : REWARD_TYPES

func is_reward() -> bool:
	if reward_type != REWARD_TYPES.N_A:
		return true
	else : return false
