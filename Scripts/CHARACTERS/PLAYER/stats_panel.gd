extends Panel

var car : CarData


@onready var fuel: Label = $HBoxContainer/Stats/Fuel
@onready var speed: Label = $HBoxContainer/Stats/Speed
@onready var torque: Label = $HBoxContainer/Stats/Torque
@onready var dmg: Label = $HBoxContainer/Stats/Dmg
@onready var drift: Label = $HBoxContainer/Stats/Drift
@onready var tires: Label = $HBoxContainer/Stats/Tires
@onready var dash_lenght: Label = $HBoxContainer/Stats/DashLenght
@onready var dash_dmg: Label = $HBoxContainer/Stats/DashDmg

@onready var fuel_lvl: Label = $HBoxContainer/Levels/Fuel_lvl
@onready var speed_lvl: Label = $HBoxContainer/Levels/Speed_lvl
@onready var torque_lvl: Label = $HBoxContainer/Levels/Torque_lvl
@onready var dmg_lvl: Label = $HBoxContainer/Levels/Dmg_lvl
@onready var drift_lvl: Label = $HBoxContainer/Levels/Drift_lvl
@onready var tires_lvl: Label = $HBoxContainer/Levels/Tires_lvl
@onready var dash_lvl: Label = $HBoxContainer/Levels/Dash_lvl
@onready var crit_lvl: Label = $HBoxContainer/Levels/Crit_lvl


func _ready() -> void:
	##-----------TEST ------------
	#CarManager.selected_car = CarManager.SEDAN
	#CarManager.selected_car.init_stats()
	
	car = CarManager.selected_car
	update_stats()
	self.visibility_changed.connect(update_stats)
	SignalManager.stats_updated.connect(_on_stats_updated)


func update_stats() -> void : 
	if car == null and CarManager.selected_car == null: 
		return
	else : 
		car = CarManager.selected_car

	
	fuel_lvl.text = str(roundi(car.max_life.get_value()))
	speed_lvl.text = str(roundi(car.display_max_speed.get_value()))
	torque_lvl.text = str(roundi(car.acceleration.get_value()))
	dmg_lvl.text = str(roundi(car.dmg.get_value()))
	drift_lvl.text = str(car.drift_turn_bonus.get_value() + car.turn_speed)
	tires_lvl.text = str(roundi(car.nitro_up.get_value()))
	dash_lvl.text = str(car.dash_duration.get_value())
	crit_lvl.text = str(car.dash_dmg_bonus.get_value())


func _on_visibility_changed() -> void:
	update_stats()

func _on_stats_updated() -> void:
	update_stats()
