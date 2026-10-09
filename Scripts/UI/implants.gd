extends VBoxContainer


func _ready() -> void:
	if !SceneManager.race_mode :
		self.hide()
