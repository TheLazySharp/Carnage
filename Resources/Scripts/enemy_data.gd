extends Resource
class_name EnemyData

@export var name : String
@export var type : EnemyManager.Enemy_Types


@export_group("VISUALS")
@export var spritesheet : Texture2D
@export var frame_size : Vector2i = Vector2i(20, 20)
## Un EnemySpriteState par ligne de la spritesheet (state_name, sheet_row, frame_count, fps, loop).
@export var sprite_states : Array[EnemySpriteState] = []
@export var scale_mod : Vector2 = Vector2.ONE
@export var sprite_angle_offset : float = 0.0 #if sprite do not face right
@export var max_rendered_instances : int = 1000
@export var max_corpses : int = 500
@export var corpse_z_index : int = -1
@export var blood_particles : PackedScene

@export_group("STATS")
@export var base_speed : float = 60
@export var base_max_life : float = 10
@export var base_dmg : float = 1
@export var base_impact_force : float = 300 #the higher, the more enemy is ejected
@export var base_knockback_friction : float = 800 #the higher, the more enemy projection is slowed
@export var speed_variation : float = 10.0
@export var level_life_boost : int = 5

@export_group("NIGHT")
@export var base_night_speed_bonus : float = 1 # +100% = modifier percent_mult
@export var base_night_dmg_bonus : float = 1 # +100% = modifier percent_mult
@export var base_night_life_bonus : float = 20 # flat modifier

@export_group("DROPS")
@export var xp_type : XPManager.XP_TYPES
@export var drops_dollar : bool = true


# ------- STATS THAT CAN BE MODIFIED -----------

enum Enemy_Stats {
	N_A,
	SPEED,
	MAX_LIFE,
	DMG,
	IMPACT_FORCE,
	KNOCKBACK_FRICTION
}
