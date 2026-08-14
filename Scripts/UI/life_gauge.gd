extends ProgressBar

@onready var life_label : Label = $LifeLabel


func _ready() -> void:
	SignalManager.player_life_changed.connect(_on_player_life_changed)


func _on_player_life_changed(current_life : int, max_life : int) -> void:
	max_value = max_life
	value = current_life
	life_label.text = str(current_life) + "/" + str(max_life)
