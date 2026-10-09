extends ProgressBar
class_name ImplantBar

var fill_style : StyleBoxFlat
var base_color : Color
var glow_tween : Tween


var implant_type : ImplantsManager.TYPES
var idx : int

var frag : int = 0
var weapons_damages : int = 0
var drift_points : int = 0
var distance : int = 0
var speed : int = 0
var laps : int = 0
var sacrifice : int = 0
var car_damages : int = 0
var car_blood_absorbed : int = 0
var car_blood_loss : int = 0

func _ready() -> void:
	if !SceneManager.race_mode :
		self.hide()
		return
	SignalManager.new_race_implants_set.connect(_set_implant_bar)
	hide()

func _set_implant_bar() -> void : 
	print("[implant bar] signal received")
	idx = int(self.name)
	implant_type = DeadLapsManager.implants_target_types[idx]
	max_value = DeadLapsManager.implants_target_values[idx]
	value = 0
	change_fill_color(get_fill_color())
	connect_implants_signals()
	self.show()
	
func change_fill_color(color : Color) -> void:
	fill_style = self.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	fill_style.bg_color = color
	base_color = color
	self.add_theme_stylebox_override("fill", fill_style)

func glow(intensity : float = 3.0, pulse_time : float = 0.4, duration : float = 0.0) -> void:
	if glow_tween:
		glow_tween.kill()
	fill_style.bg_color = base_color
	var glow_color := Color(base_color.r * intensity, base_color.g * intensity, base_color.b * intensity, base_color.a)
	var loops : int = 0
	if duration > 0.0:
		loops = max(1, int(duration / pulse_time))
	glow_tween = create_tween().set_loops(loops)
	glow_tween.tween_property(fill_style, "bg_color", glow_color, pulse_time / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	glow_tween.tween_property(fill_style, "bg_color", base_color, pulse_time / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func stop_glow() -> void:
	if glow_tween:
		glow_tween.kill()
	fill_style.bg_color = base_color

func get_fill_color() -> Color:
	match implant_type:
		ImplantsManager.TYPES.KILL:
			return Color.RED
		ImplantsManager.TYPES.WEAPONS_DAMAGES:
			return Color.GOLDENROD
		ImplantsManager.TYPES.DRIFT:
			return FontManager.dark_yellow
		ImplantsManager.TYPES.SACRIFICE:
			return FontManager.rotten_blood
		ImplantsManager.TYPES.LAPS:
			return Color.DARK_GREEN
		ImplantsManager.TYPES.SPEED:
			return Color.GREEN_YELLOW
		ImplantsManager.TYPES.DISTANCE:
			return Color.DARK_SLATE_BLUE
		_:
			return Color.WHITE

func connect_implants_signals() -> void : 
	match implant_type:
		ImplantsManager.TYPES.KILL:
			SignalManager.new_frag.connect(_on_new_frag)
		ImplantsManager.TYPES.WEAPONS_DAMAGES:
			SignalManager.weapon_damages.connect(_on_weapon_damages)
		ImplantsManager.TYPES.CAR_DAMAGES:
			SignalManager.car_damages.connect(_on_car_damages)
		ImplantsManager.TYPES.LAPS:
			SignalManager.lap_completed.connect(_on_lap_completed)
		ImplantsManager.TYPES.DRIFT:
			SignalManager.drift_ended_points.connect(_on_drift_ended_points)
		ImplantsManager.TYPES.SACRIFICE:
			SignalManager.blood_payment.connect(_on_blood_payment)
		ImplantsManager.TYPES.DISTANCE:
			SignalManager.distance_traveled.connect(_get_distance)
		ImplantsManager.TYPES.CAR_BLOOD_ABSORBED:
			SignalManager.car_blood_absorbed.connect(_on_car_blood_absorbed)
		ImplantsManager.TYPES.CAR_BLOOD_LOSS:
			SignalManager.car_blood_loss.connect(_on_car_blood_loss)



func _on_new_frag() -> void :
	frag += 1
	value = frag
	if value == max_value and SignalManager.new_frag.is_connected(_on_new_frag):
		SignalManager.new_frag.disconnect(_on_new_frag)
		glow(6,1.5)
		SignalManager.emit_signal("implant_unplugged")

func _on_weapon_damages(damages : int) -> void : 
	weapons_damages += damages
	value = weapons_damages
	if value == max_value and SignalManager.weapon_damages.is_connected(_on_weapon_damages):
		SignalManager.weapon_damages.disconnect(_on_weapon_damages)
		glow(6,1.5)
		SignalManager.emit_signal("implant_unplugged")
		
		
	
func _on_car_damages(damages : int) -> void : 
	car_damages += damages
	value = car_damages
	if value == max_value and SignalManager.car_damages.is_connected(_on_car_damages):
		SignalManager.car_damages.disconnect(_on_car_damages)
		glow(6,1.5)
		SignalManager.emit_signal("implant_unplugged")
		
		
	
func _on_lap_completed(p_laps : int) -> void : 
	laps = p_laps
	value = laps
	if value == max_value and SignalManager.lap_completed.is_connected(_on_lap_completed):
		SignalManager.lap_completed.disconnect(_on_lap_completed)
		glow(6,1.5)
		SignalManager.emit_signal("implant_unplugged")
		

func _on_drift_ended_points(p_drift_points : int) -> void:
	drift_points += p_drift_points
	value = drift_points
	if value == max_value and SignalManager.drift_ended_points.is_connected(_on_drift_ended_points):
		SignalManager.drift_ended_points.disconnect(_on_drift_ended_points)
		glow(6,1.5)
		SignalManager.emit_signal("implant_unplugged")
		

func _on_blood_payment(p_blood : int) -> void : 
	sacrifice += p_blood
	value = sacrifice
	if value == max_value and SignalManager.blood_payment.is_connected(_on_blood_payment):
		SignalManager.blood_payment.disconnect(_on_blood_payment)
		glow(6,1.5)
		SignalManager.emit_signal("implant_unplugged")
		

func _get_distance(p_distance : int) -> void : 
	distance += p_distance
	value = distance
	if value == max_value and SignalManager.distance_traveled.is_connected(_get_distance):
		SignalManager.distance_traveled.disconnect(_get_distance)
		glow(6,1.5)
		SignalManager.emit_signal("implant_unplugged")
		

func _on_car_blood_absorbed(p_blood : int) -> void : 
	car_blood_absorbed += p_blood
	value = car_blood_absorbed
	if value == max_value and SignalManager.car_blood_absorbed.is_connected(_on_car_blood_absorbed):
		SignalManager.car_blood_absorbed.disconnect(_on_car_blood_absorbed)
		glow(6,1.5)
		SignalManager.emit_signal("implant_unplugged")
		
		
func _on_car_blood_loss(p_blood : int) -> void : 
	car_blood_loss += p_blood
	value = car_blood_loss
	if value == max_value and SignalManager.car_blood_loss.is_connected(_on_car_blood_loss):
		SignalManager.car_blood_loss.disconnect(_on_car_blood_loss)
		glow(6,1.5)
		SignalManager.emit_signal("implant_unplugged")
		
