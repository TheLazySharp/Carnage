class_name CrackPulse
extends Node
## Drives the glowing pulse of one crack. Added as a CHILD of the
## CrackNetworkGenerator so the crack keeps its own script.
##
## Animates the parent's `modulate`, never self_modulate: the pixels are drawn
## by the DrawSurface child, which self_modulate would not reach.

var color_low : Color = Color(0.35, 0.02, 0.02, 1.0)
var color_high : Color = Color(5.913, 0.545, 0.268)
var duration : float = 1.2
var start_delay : float = 0.0

var _target : CanvasItem = null
var _tween : Tween = null


func _ready() -> void:
	_target = get_parent() as CanvasItem
	if _target == null:
		push_error("[CrackPulse] parent must be a CanvasItem")
		return
	_target.modulate = color_low
	_start()


func _start() -> void:
	# The delay is awaited OUTSIDE the loop: a tween_interval inside a looping
	# tween would replay the pause on every cycle.
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	if not is_instance_valid(_target):
		return
	_tween = create_tween().set_loops()
	_tween.tween_property(_target, "modulate", color_high, duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_target, "modulate", color_low, duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func stop() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
