extends CharmEffect
## rose: activate spike on drift


func activate(_p_charm : CharmData) -> void:
	SignalManager.emit_signal("active_spikes",true)


func deactivate() -> void:
	SignalManager.emit_signal("active_spikes",false)
