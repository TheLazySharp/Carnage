extends CharmEffect
## Dart: when a perfect hit projectile bursts on other enemies, the driver regains p_value blood per enemy hit

const FEEDBACK_INTERVAL : float = 0.5  # real seconds: bursts chain in a horde, the feedback must not loop

var blood_per_victim : float = 0.0
var last_feedback_time : float = -1000.0


func activate(p_charm : CharmData) -> void:
	blood_per_victim = p_charm.p_value
	SignalManager.drift_hit_chained.connect(_on_drift_hit_chained)


func deactivate() -> void:
	if SignalManager.drift_hit_chained.is_connected(_on_drift_hit_chained):
		SignalManager.drift_hit_chained.disconnect(_on_drift_hit_chained)


func _on_drift_hit_chained(victim_count : int) -> void:
	SignalManager.emit_signal("survivor_blood_gained",roundi(blood_per_victim * victim_count))
	var now : float = Time.get_ticks_msec() / 1000.0
	if now - last_feedback_time >= FEEDBACK_INTERVAL:
		last_feedback_time = now
		SignalManager.emit_signal("charm_triggered",ShopManager.CONST_REFS.Charm_Dart)
