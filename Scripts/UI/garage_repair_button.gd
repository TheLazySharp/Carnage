extends Button

var repair_done : bool = false
var max_repair_cost : int
var actual_repair_cost : int
var cost_str : String
@onready var fuel_gauge: ProgressBar = $"../Repair/FuelGauge"
@onready var life_label: Label = $"../Repair/FuelGauge/LifeLabel"
@onready var parts_q: Label = $"../Repair/PartsQ"

var font_button : Array = FontManager.FONTS[FontManager.types.BUTTON]
var font_button_focus : Array = FontManager.FONTS[FontManager.types.BUTTON_FOCUS]
var font_button_pressed : Array = FontManager.FONTS[FontManager.types.BUTTON_PRESSED]
var font_button_hover : Array = FontManager.FONTS[FontManager.types.BUTTON_HOVER]

var car : CarData = CarManager.selected_car
	#----------TEST---------------#
#var car : CarData

func _ready() -> void:
	##----------TEST---------------#
	#CarManager.selected_car = CarManager.cars[0]
	#car = CarManager.selected_car
	
	add_theme_font_override("font",font_button[0])
	add_theme_font_size_override("font_size",font_button[1])
	add_theme_color_override("font_color",font_button[2])
	add_theme_color_override("font_focus_color",font_button_focus[2])
	add_theme_color_override("font_pressed_color",font_button_pressed[2])
	add_theme_color_override("font_hover_color",font_button_hover[2])
	
	var new_stylebox : StyleBox = get_theme_stylebox("focus")
	new_stylebox.border_color = FontManager.dark_yellow
	add_theme_stylebox_override("focus",new_stylebox)
	
	
	
	fuel_gauge.max_value = car.max_life
	fuel_gauge.value = StatsManager.current_life
	parts_q.text = str(InventoryManager.auto_parts)



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
	parts_q.text = str(InventoryManager.auto_parts)
	


func _on_pressed() -> void:
	if repair_done:
		return
	repair_done = true
	actual_repair_cost = min(max_repair_cost,InventoryManager.auto_parts)
	StatsManager.current_life += actual_repair_cost
	InventoryManager.auto_parts -= actual_repair_cost
	
	
	
