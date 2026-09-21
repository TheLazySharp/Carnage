extends ProgressBar

@onready var life_label : Label = $LifeLabel
@onready var car_neons : CarNeons = get_tree().get_first_node_in_group(&"car_neons") as CarNeons

var neons_call_threshold : float = 0.15

func _ready() -> void:
	SignalManager.player_life_changed.connect(_on_player_life_changed)


func _on_player_life_changed(current_life : int, max_life : int) -> void:
	max_value = max_life
	value = current_life
	life_label.text = str(current_life) + "/" + str(max_life)
	if value < max_value * neons_call_threshold:
		car_neons.play(&"low_health", Color(1.0, 0.05, 0.02, 1.0), CarNeons.Pattern.BLINK, CarNeons.HOLD_UNTIL_STOP, CarNeons.PRIORITY_LOW_HEALTH, 0.3)
	if value >= max_value * neons_call_threshold:
		car_neons.stop(&"low_health")
