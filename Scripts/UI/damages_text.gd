class_name Damage_label
extends Label

var damage_label_tween : Tween
var font_vfx : Array = FontManager.FONTS[FontManager.types.VFX]

var in_use: bool = false

func _ready() -> void:
	SignalManager.game_paused.connect(_on_game_paused)
	add_theme_font_override("font",font_vfx[0])
	add_theme_font_size_override("font_size",font_vfx[1])
	add_theme_color_override("font_color",font_vfx[2])



func display_damages(damages_value : int, pos : Vector2) -> void : 
	in_use = true
	show()
	self.text = str(damages_value)
	global_position = pos
	
	damage_label_tween = get_tree().create_tween()
	damage_label_tween.finished.connect(_on_tween_finished)
	damage_label_tween.set_parallel(true)
	damage_label_tween.tween_property(self,"scale",Vector2(1.3,1.3),0.5)
	damage_label_tween.tween_property(self,"scale",Vector2.ZERO,0.5).set_delay(0.5)
	damage_label_tween.tween_property(self,"global_position:y",global_position.y - 120,1.5)


func _on_game_paused(game_is_paused : bool) -> void :
	if game_is_paused and self.in_use:
		damage_label_tween.pause()
	elif !game_is_paused and self.in_use : 
		damage_label_tween.play()
		
func _on_tween_finished()-> void : 
	in_use = false
	hide()
