extends Button

var repair_done : bool = false
var max_repair_cost : int
var actual_repair_cost : int
var cost_str : String

var font_button : Array = FontManager.FONTS[FontManager.types.BUTTON]
var font_button_focus : Array = FontManager.FONTS[FontManager.types.BUTTON_FOCUS]
var font_button_pressed : Array = FontManager.FONTS[FontManager.types.BUTTON_PRESSED]
var font_button_hover : Array = FontManager.FONTS[FontManager.types.BUTTON_HOVER]
@onready var repair_label: Label = $Repair
@onready var cost_label: Label = $Cost
@onready var car_icon: TextureRect = $Car


var car : CarData = CarManager.selected_car


func _ready() -> void:
	add_theme_font_override("font",font_button[0])
	add_theme_font_size_override("font_size",font_button[1])
	add_theme_color_override("font_color",font_button[2])
	add_theme_color_override("font_focus_color",font_button_focus[2])
	add_theme_color_override("font_pressed_color",font_button_pressed[2])
	add_theme_color_override("font_hover_color",font_button_hover[2])
	
	var new_stylebox : StyleBox = get_theme_stylebox("focus")
	new_stylebox.border_color = FontManager.dark_yellow
	add_theme_stylebox_override("focus",new_stylebox)
	

func _process(_delta: float) -> void:
	max_repair_cost = int((car.max_life.get_value() - car.current_life))
	cost_label.text = str(mini(max_repair_cost,InventoryManager.blood_tank_q))
	if max_repair_cost <= InventoryManager.blood_tank_q:
		repair_label.add_theme_color_override("font_color",Color.BLACK)
		cost_label.add_theme_color_override("font_color",Color.BLACK)
	else :
		repair_label.add_theme_color_override("font_color",Color.RED)
		cost_label.add_theme_color_override("font_color",Color.RED)
		

func _on_pressed() -> void:
	if repair_done:
		return
	repair_done = true
	actual_repair_cost = min(max_repair_cost,InventoryManager.blood_tank_q)
	car.current_life += actual_repair_cost
	InventoryManager.blood_tank_q -= actual_repair_cost
	BloodBars.update_blood_tank()
	BloodBars.update_car_blood()
	SignalManager.emit_signal("update_fortune")
