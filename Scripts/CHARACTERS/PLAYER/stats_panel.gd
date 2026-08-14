extends Panel

var car : CarData

@onready var life_bar: ProgressBar = $HBoxContainer/Levels/LifeBar
@onready var fuel_bar: ProgressBar = $HBoxContainer/Levels/FuelBar
@onready var speed_bar: ProgressBar = $HBoxContainer/Levels/SpeedBar
@onready var torque_bar: ProgressBar = $HBoxContainer/Levels/TorqueBar
@onready var drift_bar: ProgressBar = $HBoxContainer/Levels/DriftBar
@onready var damages_bar: ProgressBar = $HBoxContainer/Levels/DamagesBar
@onready var seats_q: Label = $HBoxContainer/Levels/SeatsQ



func _ready() -> void:
	##-----------TEST ------------
	#CarManager.selected_car = CarManager.SEDAN
	#CarManager.selected_car.init_stats()
	
	car = CarManager.selected_car
	update_stats()
	self.visibility_changed.connect(update_stats)
	SignalManager.stats_updated.connect(_on_stats_updated)
	
	life_bar.max_value = StatsManager.max_life
	fuel_bar.max_value = StatsManager.max_fuel
	speed_bar.max_value = StatsManager.display_max_speed
	torque_bar.max_value = StatsManager.max_torque
	drift_bar.max_value = StatsManager.max_drift
	damages_bar.max_value = StatsManager.max_damages


func update_stats() -> void : 
	if car == null and CarManager.selected_car == null: 
		return
	else : 
		car = CarManager.selected_car

	life_bar.value = car.max_life.get_value()
	fuel_bar.value = car.max_fuel.get_value()
	speed_bar.value = car.max_speed.get_value()
	torque_bar.value = car.acceleration.get_value()
	drift_bar.value = car.drift_turn_bonus.get_value()
	damages_bar.value = car.dmg.get_value()
	seats_q.text = str(car.seats)


func _on_visibility_changed() -> void:
	update_stats()

func _on_stats_updated() -> void:
	update_stats()
