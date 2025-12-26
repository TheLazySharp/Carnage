extends ProgressBar

var current_value: float
var target_value: float
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:=false

func _ready() -> void:
	current_value = value
	gm_scene.game_paused.connect(_on_game_paused)

func _process(_delta: float) -> void:
	if not game_paused:
		if value > current_value:
			animation_player.play("increasing")
			current_value = value

		if value < current_value:
			animation_player.play("decreasing")
			current_value = value
			
func _on_animation_finished(anim: StringName) -> void:
	#print("animaton finished")
	if anim == "increasing" or anim == "decreasing":
		if current_value == value:
			animation_player.stop()

func _on_game_paused(game_on_pause) -> void:
	game_paused = game_on_pause
