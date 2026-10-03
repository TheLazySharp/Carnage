extends Control

@onready var laps_label: Label = $Laps
@onready var toll: Label = $Toll
@onready var pit_stops_label: Label = $PitStops

var pit_stops : int = 0

func _ready() -> void:
	if !SceneManager.race_mode:
		self.hide()
		return
	SignalManager.lap_completed.connect(_on_lap_completed)
	DeadLapsManager.toll_blood_cost_updated.connect(_on_toll_cost_updated)
	SignalManager.pit_exited.connect(_on_pit_exited)
	
	toll.text = "TOLL " + str(DeadLapsManager.toll_blood_cost)
	pit_stops_label.text = "PITS " + str(pit_stops) + "/" + str(DeadLapsManager.max_pit_stops)

func _on_lap_completed(laps : int) -> void : 
	laps_label.text = "LAP " + str(laps)

func _on_toll_cost_updated(new_toll_cost : int) -> void : 
	toll.text = "TOLL " + str(new_toll_cost)
	
func _on_pit_exited(exited : bool) -> void : 
	if exited:
		pit_stops += 1
		pit_stops_label.text = "PITS " + str(pit_stops) + "/" + str(DeadLapsManager.max_pit_stops)
		
