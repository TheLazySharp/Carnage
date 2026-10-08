extends Label


const LOCKED_COLOR: Color = Color(0.55, 0.55, 0.55)

@export var display_time: float = 0.8
@export var fade_time: float = 0.25

var fade_tween: Tween = null


func _ready() -> void:
	modulate.a = 0.0
	SignalManager.maneuver_performed.connect(_on_maneuver_performed)
	SignalManager.maneuver_locked.connect(_on_maneuver_locked)


func _on_maneuver_performed(maneuver_type: ManeuverManager.Type, intensity: float, drift_level: int, is_amplified: bool, _attack_angle: float) -> void:
	# Intensity shown as a percentage to help tuning the thresholds
	var label_text: String = "%s  %d%%" % [ManeuverManager.get_maneuver_name(maneuver_type), roundi(intensity * 100.0)]
	if drift_level > 0:
		label_text += "  LV%d" % (drift_level + 1)
	if is_amplified:
		label_text += "  DASH!"
	_show(label_text, Color.WHITE)


func _on_maneuver_locked(maneuver_type: ManeuverManager.Type) -> void:
	_show("%s  LOCKED" % ManeuverManager.get_maneuver_name(maneuver_type), LOCKED_COLOR)


func _show(label_text: String, color: Color) -> void:
	text = label_text
	# self_modulate for the color, modulate.a for the fade: they don't overwrite each other
	self_modulate = color
	if fade_tween != null:
		fade_tween.kill()
	modulate.a = 1.0
	fade_tween = create_tween()
	fade_tween.tween_interval(display_time)
	fade_tween.tween_property(self, "modulate:a", 0.0, fade_time)
