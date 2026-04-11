extends Button

var repair_done : bool = false
var max_repair_cost : int
var actual_repair_cost : int
var cost_str : String
var car : CarData = CarManager.selected_car
@onready var fuel_gauge: ProgressBar = $".."
@onready var life_label: Label = $"../LifeLabel"



func _ready() -> void:
	fuel_gauge.max_value = car.max_life
	fuel_gauge.value = StatsManager.current_life



func _process(_delta: float) -> void:
	max_repair_cost = (car.max_life - StatsManager.current_life) 
	cost_str = str(max_repair_cost)
	if max_repair_cost <= InventoryManager.auto_parts:
		self.add_theme_color_override("font_color",Color.BLACK)
	else :
		self.add_theme_color_override("font_color",Color.RED)
		
	self.text = "REPAIR : " + cost_str
	fuel_gauge.value = StatsManager.current_life
	life_label.text = str(StatsManager.current_life) + "/" + str(car.max_life)


func _on_pressed() -> void:
	if repair_done:
		return
	repair_done = true
	actual_repair_cost = min(max_repair_cost,InventoryManager.auto_parts)
	StatsManager.current_life += actual_repair_cost
	InventoryManager.auto_parts -= actual_repair_cost
	
	
	
