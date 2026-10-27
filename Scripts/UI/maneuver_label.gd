extends Label


const LOCKED_COLOR: Color = Color(0.55, 0.55, 0.55)
var font_UX_S_Y : Array = FontManager.FONTS[FontManager.types.UX_S_YELLOW]

@export var display_time: float = 0.8
@export var fade_time: float = 0.25

var fade_tween: Tween = null
var pop_tween: Tween = null
var lucky_pending: bool = false  # the dice charm amplified the maneuver about to be rated
const JUICE = preload("uid://dbohpdgym7v6q")

func _ready() -> void:
	modulate.a = 0.0
	SignalManager.maneuver_locked.connect(_on_maneuver_locked)
	SignalManager.maneuver_rated.connect(_on_maneuver_rated)
	SignalManager.charm_triggered.connect(_on_charm_triggered)
	add_theme_font_override("font",font_UX_S_Y[0])
	add_theme_font_size_override("font_size",font_UX_S_Y[1])
	add_theme_color_override("font_color",font_UX_S_Y[2])


## The ComboManager rated the maneuver: DASH / PERFECT HIT prefixes, drift charge as ! / !! / !!!
func _on_maneuver_rated(maneuver_type: ManeuverManager.Type, drift_level: int, is_amplified: bool, perfect_hit: bool) -> void:
	var label_text: String = LoadoutManager.get_maneuver_display_name(maneuver_type)
	if perfect_hit:
		label_text = "%s  %s" % [tr("MANEUVER_PERFECT_HIT"), label_text]
	if is_amplified:
		# Amplified by the dice charm instead of the dash: LUCKY
		var amplify_key: String = "MANEUVER_LUCKY" if lucky_pending else "MANEUVER_DASH"
		label_text = "%s  %s" % [tr(amplify_key), label_text]
	lucky_pending = false
	# One ! per drift charge tier reached (no charge = nothing)
	if drift_level > 0:
		label_text += " " + "!".repeat(drift_level)
	_show(label_text, Color.WHITE)
	_pop()


func _on_maneuver_locked(maneuver_type: ManeuverManager.Type) -> void:
	_show("%s  LOCKED" % LoadoutManager.get_maneuver_display_name(maneuver_type), LOCKED_COLOR)

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

## Big then back to size, in real time: the hit stop of the maneuver does not freeze it
func _pop() -> void:
	if pop_tween != null:
		pop_tween.kill()
	pivot_offset = size * 0.5  # grows from its centre
	scale = Vector2.ONE * JUICE.maneuver_name_pop_scale
	pop_tween = create_tween().set_ignore_time_scale(true)
	pop_tween.tween_property(self, "scale", Vector2.ONE, JUICE.maneuver_name_pop_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## The dice charm fires right before its maneuver is rated (same frame)
func _on_charm_triggered(ref: int) -> void:
	if ref == ShopManager.CONST_REFS.Charm_dices:
		lucky_pending = true
