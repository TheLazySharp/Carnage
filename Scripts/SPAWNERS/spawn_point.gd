extends Marker2D

@onready var on_screen_notifier: VisibleOnScreenNotifier2D = $OnScreenNotifier

func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	if on_screen_notifier.is_on_screen():
		hide()
	else:
		show()
