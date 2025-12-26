extends Marker2D

@onready var label = get_node("Label")
var this_label_text = 0

func _ready():
	label.set_text(str(this_label_text))

func _on_timer_timeout() -> void:
	queue_free()
