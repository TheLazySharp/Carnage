extends Resource
class_name EnemyData

@export var name : String
@export var sprite : Texture2D # 1 ROW of sprites

@export_group("STATS")
@export var base_speed : float = 60
@export var base_max_life : float = 10
@export var base_dmg : float = 1
@export var xp_type : XPManager.XP_TYPES
@export var base_impact_force : float = 300 #the higher, the more enemy is ejected
@export var base_knockback_friction : float = 800 #the higher, the more enemy projection is slowed


@export_group("DATA")
@export var base_night_speed_bonus : float = 1 # +100% = modifier percent_mult
@export var base_night_dmg_bonus : float = 1 # +100% = modifier percent_mult
@export var base_night_life_bonus : float = 20 # flat modifier
@export var type : EnemyManager.Enemy_Types
@export var scale_mod : Vector2 = Vector2.ONE
@export var level_life_boost : int = 5
@export var atlas_row : int = 0 # enemies sprite contained in global atlas. One row = 1 enemy


# ------- STATS THAT CAN BE MODIFIED -----------

enum Enemy_Stats {
	N_A,
	SPEED,
	MAX_LIFE,
	DMG,
	IMPACT_FORCE,
	KNOCKBACK_FRICTION
}
