extends Marker2D

#PULLING CHANGES TEST

@export var speed:int 
@export var auto_scroll := true

var game_paused:= false

func _physics_process(delta: float) -> void:
	if not game_paused:
		if auto_scroll:
			var next_position: Vector2 = global_position + Vector2.DOWN.normalized() * speed * delta
			global_position = next_position


func _on_game_paused(game_on_pause : bool) -> void:
		game_paused = game_on_pause
