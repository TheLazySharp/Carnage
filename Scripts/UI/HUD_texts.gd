extends Control

@onready var ready_go: Label = $ReadyGo
@onready var horde: Label = $Horde
@onready var danger_arrows: Control = $DangerArrows

@onready var car: CharacterBody2D = $"/root/World/Car"


func _ready() -> void:
	car.start_time.connect(_on_start_time)
	car.engine_ignited.connect(_on_car_ready)
	SignalManager.coloss_incoming.connect(_on_coloss_incoming)
	SignalManager.day_time_end.connect(_on_day_timer_end)

	
	
	
	
	self.show()
	for i in self.get_children(false).size():
		get_child(i,false).hide()
		
	
func _on_car_ready() -> void : 
	if car.visible:
		ready_go.show()
		ready_go.text = "READY ?"

func _on_start_time(start : bool) -> void : 
	if start:
		ready_go.text = "GO !"
		await get_tree().create_timer(SceneManager.ready_go_timer).timeout
		ready_go.hide()

func _on_coloss_incoming() -> void : 
	horde.show()
	danger_arrows.show()
	horde.text = " DANGER INCOMING !! "

func _on_day_timer_end(timer_stop : bool) -> void : 
	if timer_stop:
		horde.hide()
		danger_arrows.hide()
		
		
		
