extends CPUParticles2D

@onready var timer: Timer = $Timer
@onready var crush_sfx: AudioStreamPlayer2D = $CrushSfx

var game_paused:=false


func _ready() -> void:
	#SignalManager.game_paused.connect(_on_game_paused)
	one_shot = true
	crush_sfx.play()

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

func _on_game_paused(game_on_pause : bool) -> void:
	game_paused = game_on_pause
