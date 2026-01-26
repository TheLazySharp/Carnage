extends Marker2D

@onready var label : Label = get_node("Label")
var this_label_text : int = 0

func _ready() -> void:
	label.set_text(str(this_label_text))

func _on_timer_timeout() -> void:
	queue_free()
