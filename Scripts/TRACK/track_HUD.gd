extends Control

@onready var laps_label: Label = $Laps

func _ready() -> void:
	if !SceneManager.race_mode:
		self.hide()
		return
	SignalManager.lap_completed.connect(_on_lap_completed)

func _on_lap_completed(laps : int) -> void : 
	laps_label.text = "LAP " + str(laps)
