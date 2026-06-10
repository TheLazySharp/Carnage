extends Button

var repair_done : bool = false
var max_repair_cost : int
var actual_repair_cost : int
var cost_str : String
@onready var fuel_gauge: ProgressBar = $"../Repair/FuelGauge"
@onready var life_label: Label = $"../Repair/FuelGauge/LifeLabel"
@onready var fortune_q: Label = $"../Repair/FortuneQ"


var font_button : Array = FontManager.FONTS[FontManager.types.BUTTON]
var font_button_focus : Array = FontManager.FONTS[FontManager.types.BUTTON_FOCUS]
var font_button_pressed : Array = FontManager.FONTS[FontManager.types.BUTTON_PRESSED]
var font_button_hover : Array = FontManager.FONTS[FontManager.types.BUTTON_HOVER]
@onready var repair_label: Label = $HBoxContainer/Repair
@onready var cost_label: Label = $HBoxContainer/Cost



var car : CarData = CarManager.selected_car
	#----------TEST---------------#
#var car : CarData

func _ready() -> void:
	##----------TEST---------------#
	#CarManager.selected_car = CarManager.cars[0]
	#car = CarManager.selected_car
	#car.init_stats()
	
	add_theme_font_override("font",font_button[0])
	add_theme_font_size_override("font_size",font_button[1])
	add_theme_color_override("font_color",font_button[2])
	add_theme_color_override("font_focus_color",font_button_focus[2])
	add_theme_color_override("font_pressed_color",font_button_pressed[2])
	add_theme_color_override("font_hover_color",font_button_hover[2])
	
	var new_stylebox : StyleBox = get_theme_stylebox("focus")
	new_stylebox.border_color = FontManager.dark_yellow
	add_theme_stylebox_override("focus",new_stylebox)
	
	fuel_gauge.max_value = car.max_life.get_value()
	fuel_gauge.value = car.current_life
	fortune_q.text = str(InventoryManager.fortune)

func _process(_delta: float) -> void:
	max_repair_cost = int((car.max_life.get_value() - car.current_life))
	cost_label.text = str(max_repair_cost)
	if max_repair_cost <= InventoryManager.fortune:
		repair_label.add_theme_color_override("font_color",Color.BLACK)
		cost_label.add_theme_color_override("font_color",Color.BLACK)
	else :
		repair_label.add_theme_color_override("font_color",Color.RED)
		cost_label.add_theme_color_override("font_color",Color.RED)
		
	#self.text = "REPAIR : " + cost_str
	fuel_gauge.value = car.current_life
	life_label.text = str(car.current_life) + "/" + str(int(car.max_life.get_value()))
	fuel_gauge.max_value = car.max_life.get_value()
	fortune_q.text = str(InventoryManager.fortune)
	


func _on_pressed() -> void:
	if repair_done:
		return
	repair_done = true
	actual_repair_cost = min(max_repair_cost,InventoryManager.fortune)
	car.current_life += actual_repair_cost
	InventoryManager.fortune -= actual_repair_cost
	SignalManager.emit_signal("update_fortune")
