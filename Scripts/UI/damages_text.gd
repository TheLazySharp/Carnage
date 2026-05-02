extends Label

var damage_label_tween : Tween
var font_sfx : Array = FontManager.FONTS[FontManager.types.SFX]

func _ready() -> void:
	add_theme_font_override("font",font_sfx[0])
	add_theme_font_size_override("font_size",font_sfx[1])
	add_theme_color_override("font_color",font_sfx[2])
	
	SignalManager.game_paused.connect(_on_game_paused)
	damage_label_tween = get_tree().create_tween()
	damage_label_tween.set_parallel(true)
	damage_label_tween.tween_property(self,"scale",Vector2(1.3,1.3),0.5)
	damage_label_tween.tween_property(self,"scale",Vector2.ZERO,0.5).set_delay(0.5)
	damage_label_tween.tween_property(self,"global_position:y",global_position.y - 120,1.5)
	await damage_label_tween.finished
	queue_free()

func _on_game_paused(game_is_paused : bool) -> void :
	if game_is_paused:
		damage_label_tween.pause()
	else : 
		damage_label_tween.play()
