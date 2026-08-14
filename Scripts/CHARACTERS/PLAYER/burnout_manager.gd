extends Node2D
class_name BurnoutManager

signal rev_changed(is_revving : bool)
signal burnout_launched
signal burnout_ended

@export var enable_input_buffer : bool = true

enum RevState { IDLE, CHARGING }

const REV_MAX_SPEED : float = 30.0      # px/s : below, car is stopped
const REV_MIN_CHARGE : float = 0.25     # s : min charge before a release launch burnout
const REV_CANCEL_SPEED : float = 60.0   # px/s : rev cancel if car is moved
const REV_PRESS_BUFFER : float = 0.2    # s : laps for a valid fresh press
const REV_RELEASE_GRACE : float = 0.1   # s : if accel release before drift

var player : CarData
var burn_anims : Array[AnimatedSprite2D] = []

var state : RevState = RevState.IDLE
var rev_charge : float = 0.0
var press_buffer : float = 0.0
var release_grace : float = 0.0


func init_burnout(data : CarData, left_anim : AnimatedSprite2D, right_anim : AnimatedSprite2D) -> void:
	player = data
	burn_anims = [left_anim, right_anim]
	for anim : AnimatedSprite2D in burn_anims:
		anim.hide()
		anim.animation_finished.connect(_on_burn_anim_finished.bind(anim))


func is_revving() -> bool:
	return state == RevState.CHARGING


## called from car physics update and return throttle
func process_burnout(delta : float, throttle : float, speed : float) -> float:
	var accel_held : bool = Input.is_action_pressed("accelerate")
	var drift_held : bool = Input.is_action_pressed("drift")

	match state:
		RevState.IDLE:
			var fresh_press : bool = (Input.is_action_just_pressed("drift") or Input.is_action_just_pressed("accelerate")) \
				and accel_held and drift_held

			if fresh_press and enable_input_buffer:
				press_buffer = REV_PRESS_BUFFER
			else:
				press_buffer = maxf(press_buffer - delta, 0.0)

			var press_valid : bool = fresh_press or (press_buffer > 0.0 and accel_held and drift_held)
			if press_valid and speed < REV_MAX_SPEED:
				start_charging()
				throttle = 0.0

		RevState.CHARGING:
			rev_charge += delta
			throttle = 0.0

			if !accel_held:
				release_grace += delta
			else:
				release_grace = 0.0

			var accel_ok : bool = accel_held or (enable_input_buffer and release_grace <= REV_RELEASE_GRACE)

			if speed > REV_CANCEL_SPEED or !accel_ok:
				cancel()
			elif Input.is_action_just_released("drift"):
				if rev_charge >= REV_MIN_CHARGE:
					throttle = launch()
				else:
					cancel()
	return throttle


func start_charging() -> void:
	state = RevState.CHARGING
	rev_charge = 0.0
	press_buffer = 0.0
	release_grace = 0.0
	rev_changed.emit(true)
	for anim : AnimatedSprite2D in burn_anims:
		anim.show()
		if !anim.is_playing():
			anim.play("fadeIn")


func cancel() -> void:
	stop_rev()
	burnout_ended.emit()


func launch() -> float:
	stop_rev()
	burnout_ended.emit()
	burnout_launched.emit()
	return float(player.burnout_boost)


func stop_rev() -> void:
	state = RevState.IDLE
	rev_charge = 0.0
	release_grace = 0.0
	rev_changed.emit(false)
	for anim : AnimatedSprite2D in burn_anims:
		anim.play("fadeOut")


func _on_burn_anim_finished(anim : AnimatedSprite2D) -> void:
	if state == RevState.CHARGING:
		anim.play("idle")
	elif anim.animation == "fadeOut":
		anim.stop()
		anim.hide()
	else:
		anim.play("fadeOut")
