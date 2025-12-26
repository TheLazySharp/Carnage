extends AnimationPlayer

@onready var xp_manager: Node = $"/root/XPManager"

var animation:= false

func _ready() -> void:
	xp_manager.animation_play.connect(_play_animation)


func _process(_delta: float) -> void:
	pass

func _play_animation(animation_is_playing):
	animation = animation_is_playing
	if animation:
		play("level_up_anim")
	else: return
