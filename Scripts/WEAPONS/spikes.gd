extends Area2D

var knockback_force : int = 30
var velocity : Vector2 = Vector2.ZERO

@export var death_type : EnemyManager.DEATH_TYPES = EnemyManager.DEATH_TYPES.DEFAULT
@onready var drift_manager : Node2D = $/root/World/Car/DriftManager
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var variant_sprite : Sprite2D = $Sprite2D


func _ready() -> void:
	variant_sprite.frame = randi() % (variant_sprite.hframes * variant_sprite.vframes)
	drop()

func _on_area_entered(area: Area2D) -> void:
	if "get_damages" in area and area.is_in_group("ennemies"):
		# reminder : func get_damages(damages: int, hit_direction: Vector2 = Vector2.ZERO, knockback_force: float = 0.0, death_type: EnemyManager.Death_Types = DEFAULT) -> void:
		var dealt: int = roundi(drift_manager.spikes_damages.get_value())
		area.get_damages(dealt, velocity, knockback_force, death_type)


func drop() -> void : 
	audio_stream_player.play()
