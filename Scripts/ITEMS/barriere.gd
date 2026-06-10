extends Node2D


@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	SignalManager.day_time_end.connect(_on_day_timer_ended)
	

func _on_day_timer_ended(timer_ended : bool) -> void : 
	if timer_ended:
		animation_player.play("opening")


func _on_warp_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		animation_player.play("closing")
		StatsManager.total_drift = body.get_node("DriftManager").total_drift_points
		await get_tree().create_timer(2).timeout
		SignalManager.emit_signal("next_day")
		SceneManager.load_level(SceneManager.SCENES.CAR_LEVELUP)
