extends CPUParticles2D

@onready var timer: Timer = $Timer
#@onready var gm_scene: Node = $"/root/World/game_manager"
var game_paused:=false


func _ready() -> void:
	#gm_scene.game_paused.connect(_on_game_paused)
	one_shot = true

func _process(_delta: float) -> void:
	if !game_paused:
		var tween := create_tween()
		tween.tween_property(
			self,
			"color:a",
			0.0,
			timer.wait_time
		)
		tween.tween_callback(self.queue_free)
	
	if game_paused: timer.paused = true
	else: timer.paused = false
	
func _on_timer_timeout() -> void:
	if self:
		queue_free()

func _on_game_paused(game_on_pause) -> void:
	game_paused = game_on_pause
