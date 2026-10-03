class_name EnemySpriteState
extends Resource

@export var state_name: String = "walk"
## Cell size of this atlas. ZERO = use EnemyData.frame_size.
## Used only when is_death_state is true: replaces state_name as the state key.
@export var death_type : EnemyManager.DEATH_TYPES = EnemyManager.DEATH_TYPES.DEFAULT
@export var frame_size : Vector2i = Vector2i.ZERO
#@export var frame_count: int = 11
@export var fps: float = 10.0
@export var loop: bool = true
@export var is_death_state: bool = false
@export var spritesheet : Texture2D
